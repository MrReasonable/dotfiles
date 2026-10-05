#!/usr/bin/env bash
# Set up a new machine with these dotfiles: macOS, Linux (Debian/Ubuntu) or
# Windows via WSL2 (run it inside Ubuntu). Safe to re-run.
#
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/MrReasonable/dotfiles/main/install.sh)"
#
# Any arguments are passed to `chezmoi init`, e.g. to answer its questions
# without asking (keys are the questions as chezmoi asks them):
#   --promptString "Name=...,Github Username=...,Github email address=...,GPG Signing Key=..."
#
# It doesn't create SSH or GPG keys (they're secrets); it checks for them and
# says what's missing at the end. See README.md for the manual steps.
#
# At the end it offers to remove leftovers this setup replaces (other chezmoi
# copies, Linux Homebrew, mise, snap Neovim), asking before each one.
# DOTFILES_YES=1 answers yes to all of them (unattended runs).
set -euo pipefail

REPO=MrReasonable
SSH_URL=git@github.com:MrReasonable/dotfiles.git

say()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }
todo=()

# --- which platform ----------------------------------------------------------
os=$(uname -s)
wsl=false
if [ "$os" = Linux ] && grep -qi microsoft /proc/version 2>/dev/null; then wsl=true; fi
case "$os" in
  Darwin) say "macOS" ;;
  Linux)  say "Linux$($wsl && echo ' (WSL)')"
          have apt-get || { warn "Only Debian/Ubuntu (apt) is automated; install the README's packages yourself, then re-run."; exit 1; } ;;
  *)      warn "Unsupported OS: $os. On Windows, run this inside WSL (see README.md)."; exit 1 ;;
esac

# --- system packages ---------------------------------------------------------
if [ "$os" = Darwin ]; then
  if ! xcode-select -p >/dev/null 2>&1; then
    say "Installing the command line developer tools (accept the dialog)"
    xcode-select --install || true
    until xcode-select -p >/dev/null 2>&1; do sleep 5; done
  fi
else
  say "Installing apt packages (asks for your password)"
  sudo apt-get update -qq
  # noninteractive: a minimal install (WSL, containers) would stop to ask for a time zone
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y zsh git curl tmux gnupg build-essential unzip python3 procps file
fi

# --- Homebrew (macOS only) ---------------------------------------------------------
if [ "$os" = Darwin ]; then
  brew_bin=""
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$b" ] && { brew_bin=$b; break; }
  done
  if [ -z "$brew_bin" ]; then
    say "Installing Homebrew (asks for your password)"
    sudo -v  # unattended mode won't prompt for sudo itself
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      [ -x "$b" ] && { brew_bin=$b; break; }
    done
  fi
  eval "$("$brew_bin" shellenv)"
  # Homebrew 5 asks "Do you want to proceed?" before each install by default.
  export HOMEBREW_NO_ASK=1
  # Login shells need brew on PATH before .zshrc runs (.zshrc relies on it).
  grep -qs 'brew shellenv' "$HOME/.zprofile" ||
    echo "eval \"\$($brew_bin shellenv)\"" >> "$HOME/.zprofile"

  say "Installing Homebrew packages"
  brew install git gh tmux neovim eza gnupg pinentry-mac lazygit diff-so-fancy
  brew install --cask iterm2 font-fira-code-nerd-font
fi
# No Homebrew on Linux (it sudo-installs into /home/linuxbrew): neovim, lazygit,
# gh and diff-so-fancy come from proto there, with the other tools.

# --- chezmoi: its own installer, into ~/.local/bin, on every OS -----------------
# `update-all` keeps it current with `chezmoi upgrade`. Other copies (Homebrew's,
# an old ~/bin one) are offered for removal at the end.
export PATH="$HOME/.local/bin:$PATH"
if [ ! -x "$HOME/.local/bin/chezmoi" ]; then
  say "Installing chezmoi into ~/.local/bin"
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
fi
chezmoi() { "$HOME/.local/bin/chezmoi" "$@"; }

# --- Rust's installer (proto installs Rust through it) ------------------------
if [ ! -x "$HOME/.cargo/bin/rustup" ]; then
  say "Installing rustup"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
    sh -s -- -y --no-modify-path --default-toolchain none
fi

# --- keys: check before chezmoi (its git config signs every commit) -----------
if ! ls "$HOME"/.ssh/id_* >/dev/null 2>&1; then
  todo+=("No SSH key in ~/.ssh: create one (ssh-keygen -t ed25519) and add it to GitHub (gh auth login can upload it).")
fi
if ! gpg --list-secret-keys --with-colons 2>/dev/null | grep -q '^sec'; then
  todo+=("No GPG secret key: import yours (gpg --import private.asc), trust it, and give its ID to chezmoi (chezmoi init --prompt). Commits are signed, so they'll fail until then.")
fi

# --- the dotfiles --------------------------------------------------------------
# Update only once chezmoi has its config (written by init from your answers); a
# run that stopped after cloning but before that just runs init again.
if [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi/chezmoi.toml" ]; then
  # No --force: chezmoi asks before overwriting a file you've edited directly.
  say "Dotfiles already here; updating"
  chezmoi update
else
  say "Applying the dotfiles (asks for your name, GitHub details and GPG key ID)"
  chezmoi init --apply "$REPO" "$@"
fi

# Push over SSH once GitHub accepts this machine's key (clone was over HTTPS).
# (ssh -T exits 1 even when GitHub accepts the key, so check what it says.)
gh_ssh=$(ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)
if [[ $gh_ssh == *"successfully authenticated"* ]]; then
  chezmoi git -- remote set-url origin "$SSH_URL"
else
  todo+=("To push dotfile changes, once your SSH key is on GitHub: chezmoi git -- remote set-url origin $SSH_URL")
fi

# --- login shell -----------------------------------------------------------------
zsh_path=$(command -v zsh)
if [ "${SHELL:-}" != "$zsh_path" ] && [ "$(basename "${SHELL:-}")" != zsh ]; then
  say "Making zsh your login shell"
  grep -qx "$zsh_path" /etc/shells || echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
  chsh -s "$zsh_path" || todo+=("Couldn't change your shell: run chsh -s $zsh_path")
fi

# --- leftovers this setup replaces ------------------------------------------------
# Each is listed and removed only if you say yes (or DOTFILES_YES=1). apt
# packages are never touched: other software on a server may rely on them.
confirm() {
  [ "${DOTFILES_YES:-}" = 1 ] && return 0
  if ! { : < /dev/tty; } 2>/dev/null; then  # no terminal to ask on
    todo+=("Left in place (couldn't ask): ${1%%\?*}. Re-run in a terminal, or with DOTFILES_YES=1.")
    return 1
  fi
  local reply
  printf '%s [y/N] ' "$1" > /dev/tty
  read -r reply < /dev/tty || return 1
  [[ $reply == [yY]* ]]
}
rm_maybe_sudo() {  # remove a file, with sudo if it isn't ours to remove
  if [ -w "$(dirname "$1")" ]; then rm -f "$1"; else sudo rm -f "$1"; fi
}

# Other chezmoi copies. Homebrew's (macOS) is offered as a brew uninstall;
# anything a system package owns is left alone.
brew_prefix=/nonexistent  # never empty: "$brew_prefix"/* would then match every path
[ "$os" = Darwin ] && brew_prefix=$(brew --prefix)
if [ "$os" = Darwin ] && brew list --formula chezmoi >/dev/null 2>&1; then
  if confirm "Uninstall Homebrew's chezmoi (replaced by ~/.local/bin/chezmoi)?"; then
    brew uninstall chezmoi
  fi
fi
while IFS= read -r p; do
  [ "$p" = "$HOME/.local/bin/chezmoi" ] && continue
  case "$p" in
    "$brew_prefix"/*|/home/linuxbrew/*|"$HOME"/.linuxbrew/*) continue ;;  # Homebrew's own
  esac
  dpkg -S "$p" >/dev/null 2>&1 && continue
  if confirm "Remove old chezmoi at $p (replaced by ~/.local/bin/chezmoi)?"; then
    rm_maybe_sudo "$p"
  fi
done < <(type -aP chezmoi | awk '!seen[$0]++')

if [ "$os" = Linux ]; then
  # Linux Homebrew: nothing in this setup uses it any more.
  for prefix in /home/linuxbrew/.linuxbrew "$HOME/.linuxbrew"; do
    [ -x "$prefix/bin/brew" ] || continue
    say "Found Linux Homebrew in $prefix"
    "$prefix/bin/brew" list --formula 2>/dev/null | tr '\n' ' ' | fold -s -w 76 | sed 's/^/   /'
    echo
    if confirm "Remove it all? (only if nothing else on this machine uses these)"; then
      NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)" -- --path="$prefix" ||
        warn "Homebrew's uninstaller failed; removing the folder directly"
      if [ "$prefix" = /home/linuxbrew/.linuxbrew ]; then sudo rm -rf /home/linuxbrew; else rm -rf "$prefix"; fi
    fi
  done
  # Neovim from snap: proto provides it now.
  if have snap && snap list nvim >/dev/null 2>&1; then
    if confirm "Remove the snap Neovim (proto provides Neovim now)?"; then
      sudo snap remove nvim
    fi
  fi
fi

# mise: replaced by proto (.prototools) and direnv (.envrc).
if [ -x "$HOME/.local/bin/mise" ]; then
  if confirm "Uninstall mise and everything it installed (proto replaces it)?"; then
    "$HOME/.local/bin/mise" implode --yes --config
  fi
fi

# --- what's left -----------------------------------------------------------------
if [ "$os" = Darwin ]; then
  todo+=("iTerm2: if it was already open, quit it and run chezmoi apply to make TokyoNight its default profile.")
  todo+=("iTerm2: allow it in System Settings → Privacy & Security → Accessibility for the double-tap-Ctrl hotkey window (it asks).")
elif $wsl; then
  todo+=("Windows Terminal: install FiraCode Nerd Font on Windows and set it as the Ubuntu profile's font (README.md, Windows step 3).")
else
  todo+=("Use a Nerd Font (e.g. FiraCode Nerd Font) in the terminal you connect from, for the icons.")
fi
todo+=("Open a new terminal: the first zsh start downloads its plugins. Then run nvim once and let it install everything.")

say "Done"
for t in "${todo[@]}"; do printf ' - %s\n' "$t"; done
