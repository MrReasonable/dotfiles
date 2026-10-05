# dotfiles

My terminal setup, managed with [chezmoi](https://www.chezmoi.io): zsh (zi +
Powerlevel10k), tmux (Oh my tmux!), Neovim (AstroNvim), iTerm2, and a set of
CLI tools pinned with [proto](https://moonrepo.dev/proto). TokyoNight
everywhere, Storm in dark mode and Day in light, following the OS appearance.

Supported: **macOS**, **Linux** (Ubuntu/Debian; other distros need the
equivalent packages) and **Windows via WSL2**.

## Quick start

On macOS, Linux (Debian/Ubuntu) or inside WSL2's Ubuntu on Windows:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/MrReasonable/dotfiles/main/install.sh)"
```

[`install.sh`](install.sh) does the steps below for you: system packages,
Homebrew, Rust's installer, chezmoi and the dotfiles, zsh as your login shell,
and (macOS) iTerm2 with TokyoNight as its default profile. It asks for your
password, then chezmoi's questions (name, GitHub username and email, GPG key
ID). Your SSH and GPG keys aren't automated: it checks for them and lists
anything left to do at the end. Re-running it is safe; it updates instead.

On Windows, first do [Windows steps 1–3](#windows-wsl2) (WSL, Windows Terminal,
font), then run the line above inside Ubuntu.

The rest of this README is the same thing step by step.

- [What you get](#what-you-get)
- [macOS](#macos)
- [Linux](#linux)
- [Windows (WSL2)](#windows-wsl2)
- [After the install (all platforms)](#after-the-install-all-platforms)
- [Day to day](#day-to-day)
- [How it's put together](#how-its-put-together)

## What you get

- **zsh**: zi plugin manager in turbo mode (prompt first, plugins right
  after), Powerlevel10k, fzf-tab completion, autosuggestions, syntax
  highlighting, atuin history (Ctrl-R), zoxide (`z`), navi cheat sheets
  (Ctrl-G), a "did you know" tip at startup (`tips` for more).
- **tmux**: Oh my tmux! with a TokyoNight status bar, prefix `Ctrl-A`, a sesh
  session picker (`prefix T`), navi from any pane (`prefix Ctrl-G`), and
  Ctrl-h/j/k/l moving between tmux panes and Neovim splits alike.
- **Neovim**: AstroNvim with language support for TypeScript, Rust, Python,
  Go, C, Lua, SQL, Terraform, Ansible, shell and more; Claude Code, tests,
  git, and a built-in tutorial series (`:Tutor my-00-start`).
- **Languages and CLI tools** via proto, each pinned in
  `~/.proto/.prototools`: node, npm, pnpm, uv, rust, go, python, direnv, atuin, carapace, delta, difftastic, dust, hyperfine, jless,
  just, micromamba, navi (Linux), sd, sesh, tailspin, tlrc, watchexec, xh,
  yazi, jq (Linux), btop/git-absorb (Linux).
- **direnv** with micromamba: `cd` into a project and its environment
  activates.
- **iTerm2** (macOS): a TokyoNight profile that switches with light/dark
  mode, and a double-tap-Ctrl hotkey window.

## macOS

1. **Command line tools and Homebrew**

   ```sh
   xcode-select --install
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

   Follow the "Next steps" Homebrew prints to put `brew` on your PATH
   (it adds a `brew shellenv` line to `~/.zprofile`), then open a new
   terminal.

2. **Packages**

   ```sh
   brew install chezmoi git gh tmux neovim eza gnupg pinentry-mac \
     lazygit diff-so-fancy
   brew install --cask iterm2 font-fira-code-nerd-font
   ```

   btop, git-absorb, navi and proto are installed for you in step 5. zsh is
   already the default shell on macOS.

3. **Rust's installer** (proto manages the Rust version, but uses rustup to
   install it)

   ```sh
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --default-toolchain none
   ```

4. **SSH and GPG keys**: see [Keys](#keys). Do this before step 5 if you can:
   the git config signs every commit.

5. **Apply the dotfiles**

   ```sh
   chezmoi init --apply MrReasonable
   ```

   It asks for your name, GitHub username, GitHub email and GPG signing key
   ID (asked once, then kept in `~/.config/chezmoi/chezmoi.toml`), then
   writes the files and runs the install scripts: Homebrew formulas, proto
   and every pinned tool, the Rust toolchain, and the iTerm2 settings.

6. **iTerm2**: TokyoNight becomes the default profile on `chezmoi apply`
   (only while iTerm2 is closed; if it was open, quit it and apply again).

   - The double-tap-Ctrl hotkey window needs iTerm2 allowed in **System
     Settings → Privacy & Security → Accessibility** (it asks).
   - TokyoNight builds on iTerm2's "Default" profile, which iTerm2 creates on
     first launch. If it's ever deleted, quit iTerm2 and run
     `iterm2-default-profile` to recreate it.
   - The profile is read-only in iTerm2's settings: change it in
     `private_Library/…/DynamicProfiles/tokyonight.json` and `chezmoi apply`.

7. Carry on with [After the install](#after-the-install-all-platforms).

## Linux

Ubuntu 24.04 shown; other distros need the same packages under their own
names.

1. **Packages**

   ```sh
   sudo apt update
   sudo apt install -y zsh git curl tmux gnupg build-essential unzip python3
   chsh -s "$(command -v zsh)"   # takes effect at next login
   ```

2. **Homebrew for Linux** (for a current Neovim, lazygit and chezmoi; Ubuntu's
   own Neovim is too old for AstroNvim)

   ```sh
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
   brew install chezmoi neovim lazygit diff-so-fancy gh
   ```

   The zsh config finds Homebrew in `/home/linuxbrew/.linuxbrew` or
   `~/.linuxbrew` by itself.

3. **Rust's installer**

   ```sh
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --default-toolchain none
   ```

4. **SSH and GPG keys**: see [Keys](#keys).

5. **Apply the dotfiles**

   ```sh
   chezmoi init --apply MrReasonable
   ```

   Same prompts as on macOS. The install script then installs proto (from
   its official installer), every pinned tool, the Rust toolchain, and
   trash-cli (so `rm` goes to the trash).

6. **Font**: icons in the prompt, eza and Neovim need a Nerd Font in the
   terminal you connect *from* (e.g. FiraCode Nerd Font from
   [nerdfonts.com](https://www.nerdfonts.com/font-downloads)). Over SSH, that's
   your local machine's terminal.

7. Log out and back in (for zsh), then carry on with
   [After the install](#after-the-install-all-platforms).

Light/dark switching follows GNOME's colour scheme where it's available;
elsewhere (servers, WSL) everything stays dark.

## Windows (WSL2)

Everything here is zsh, tmux and Unix tools, so on Windows it runs inside WSL2
(Linux in a lightweight VM) with Windows Terminal in front.

1. **WSL2 and Ubuntu**: in PowerShell as Administrator:

   ```powershell
   wsl --install -d Ubuntu-24.04
   ```

   Restart when asked, then open **Ubuntu** from the Start menu and create
   your Linux user.

2. **Windows Terminal** (built into Windows 11; on Windows 10:
   `winget install Microsoft.WindowsTerminal`).

3. **Font**: download **FiraCode** from
   [nerdfonts.com](https://www.nerdfonts.com/font-downloads), unzip it,
   select the `.ttf` files and choose **Install for all users**. In Windows
   Terminal: **Settings → Ubuntu → Appearance → Font face →
   FiraCode Nerd Font**. While there, set **Settings → Startup → Default
   profile** to Ubuntu.

4. **Inside Ubuntu**, follow the [Linux](#linux) steps from step 1 (skip the
   font step; that's step 3 here).

5. Notes:
   - Keep projects inside the Linux file system (`~/projects`), not under
     `/mnt/c`: it's many times faster for git, Neovim and builds.
   - Copying in tmux reaches the Windows clipboard (Oh my tmux! uses
     `clip.exe` under WSL).
   - The theme stays TokyoNight Storm (dark); WSL can't see Windows'
     light/dark setting.

## After the install (all platforms)

1. **Open a new terminal.** The first zsh start downloads zi and all plugins
   (a minute or so, with progress messages); later starts are instant. If
   anything looks half-loaded, `exec zsh`.

2. **tmux**: run `tmux`. Oh my tmux! installs its plugins on first launch.
   Prefix is `Ctrl-A`; `prefix ?` lists the keys.

3. **Neovim**: run `nvim` and wait for the plugin and language-server
   installs to finish (`:Lazy` and `:Mason` show progress), then quit and
   reopen it. Start learning with `:Tutor my-00-start`.

4. **Atuin** (optional, for synced shell history): `atuin login` or
   `atuin register`.

5. **Check**: `chezmoi doctor` should show no errors, and `chezmoi diff`
   should be empty.

### Keys

Not stored in this repo.

- **SSH**: create a key (`ssh-keygen -t ed25519`) or restore yours, and add
  the public key to GitHub (`gh auth login` can upload it). zsh's ssh-agent
  plugin loads `~/.ssh/id_*` keys automatically.
- **GPG** (commits are signed): import your key from your backup
  (`gpg --import private.asc`), then trust it (`gpg --edit-key <id>`, `trust`,
  `5`). Use its key ID at the chezmoi prompt. On macOS, pinentry-mac asks for
  the passphrase; gpg-agent caches it for a day.
- **Pushing dotfile changes**: `chezmoi init` clones over HTTPS. To push, switch
  to SSH:

  ```sh
  chezmoi git -- remote set-url origin git@github.com:MrReasonable/dotfiles.git
  ```

## Day to day

| What | How |
| --- | --- |
| Update everything (dotfiles, packages, zsh plugins, proto tools) | `update-all` |
| Edit a dotfile | `chezmoi edit ~/.zshrc` (or edit in `~/.local/share/chezmoi`), then `chezmoi apply` |
| See what would change | `chezmoi diff` |
| Commit and push changes | `chezmoi cd`, then git as usual |
| Find a command or key | Ctrl-G (navi), `tips`, `tldr <cmd>` |
| A newer tool is out | `update-all` warns; bump the version in `dot_proto/dot_prototools.tmpl` |

## How it's put together

| Path | What |
| --- | --- |
| `dot_zshrc.tmpl` | zsh config (a chezmoi template: differs per OS) |
| `dot_p10k.zsh` | Powerlevel10k prompt (lean style) |
| `dot_tmux.conf.local` | Oh my tmux! settings, theme, key bindings |
| `.chezmoiexternal.toml` | Oh my tmux! itself and the public navi cheat sheets |
| `nvim/` | The Neovim config; `~/.config/nvim` is a symlink to it |
| `dot_proto/` | proto's tool pins (`dot_prototools.tmpl`) and plugins for tools proto doesn't know (`tool-plugins/`) |
| `run_onchange_after_install-cli-tools.sh.tmpl` | Installs proto and the pinned tools; re-runs when the pins change |
| `run_onchange_after_iterm2-settings.sh.tmpl` | iTerm2 preferences outside its profiles (macOS) |
| `private_Library/…/DynamicProfiles/tokyonight.json` | The iTerm2 profile (macOS) |
| `private_dot_local/bin/` | Helper scripts: `appearance` (light/dark), `tips-build`, `navi-cheats-build`, `iterm2-default-profile` |
| `dot_config/` | direnv (with micromamba), eza themes, navi, and others |
| `.chezmoiignore` | Files skipped per OS (e.g. `Library` off macOS) |
