#!/usr/bin/env bash
# Set up a new machine with these dotfiles: macOS, Linux (Debian/Ubuntu) or
# Windows via WSL2 (run it inside Ubuntu). Safe to re-run.
#
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/MrReasonable/dotfiles/main/install.sh)"
#
# Any arguments are passed to `chezmoi init`, e.g. to answer its prompts
# without asking:  --promptString name=...,github_username=...
#
# It doesn't create SSH or GPG keys (they're secrets); it checks for them and
# says what's missing at the end. See README.md for the manual steps.
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
  sudo apt-get install -y zsh git curl tmux direnv gnupg build-essential unzip python3 procps file
fi

# --- Homebrew ----------------------------------------------------------------
brew_bin=""
for b in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
  [ -x "$b" ] && { brew_bin=$b; break; }
done
if [ -z "$brew_bin" ]; then
  say "Installing Homebrew (asks for your password)"
  sudo -v  # unattended mode won't prompt for sudo itself
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
    [ -x "$b" ] && { brew_bin=$b; break; }
  done
fi
eval "$("$brew_bin" shellenv)"
# On macOS, login shells need brew on PATH before .zshrc runs (.zshrc relies on it).
if [ "$os" = Darwin ] && ! grep -qs 'brew shellenv' "$HOME/.zprofile"; then
  echo "eval \"\$($brew_bin shellenv)\"" >> "$HOME/.zprofile"
fi

say "Installing Homebrew packages"
if [ "$os" = Darwin ]; then
  brew install chezmoi git gh tmux neovim direnv eza gnupg pinentry-mac lazygit diff-so-fancy
  brew install --cask iterm2 font-fira-code-nerd-font
else
  # Ubuntu's own Neovim is too old for AstroNvim.
  brew install chezmoi neovim lazygit diff-so-fancy gh
fi

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
if [ -d "$HOME/.local/share/chezmoi/.git" ]; then
  say "Dotfiles already here; updating"
  chezmoi update --force
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
