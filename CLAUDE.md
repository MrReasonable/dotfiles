# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A [chezmoi](https://www.chezmoi.io) source directory (`~/.local/share/chezmoi`, repo `MrReasonable/dotfiles`) for macOS, Debian/Ubuntu Linux and WSL2: zsh (zi + Powerlevel10k), tmux (Oh my tmux!), Neovim (AstroNvim v6), iTerm2, and CLI tools pinned with proto. README.md is the user-facing doc and has a path-by-path table under "How it's put together"; keep it in step when you change behaviour it describes.

## The rule everything is built around: pinned, and 7 days old

Every external dependency is pinned exactly, and moves only once a release or commit is **7+ days old**. Three separate mechanisms do the moving. Don't bypass them: no `:Lazy update`/`:Lazy sync`, no `zi update`, no `proto upgrade`, `proto install <tool> latest` or `proto pin --global`, and no hand-editing a pin to a newer version unless the user explicitly asks.

| What | Pinned in | Moved by |
| --- | --- | --- |
| proto tools, proto itself | `dot_proto/dot_prototools.tmpl` | Renovate (`renovate.json`): patch/minor automerge after 7 days, majors open a PR |
| chezmoi, jless/git-absorb (ARM Linux cargo builds) | `.chezmoidata.toml` `[pins]` | Renovate |
| zi, zsh plugins, Oh My Zsh files, Oh my tmux, navi cheat repos | `.chezmoidata.toml` `[git_pins]` | `.github/workflows/git-pins.yml` + `.github/scripts/git_pins_bump.py` (weekly) |
| Neovim plugins | `nvim/lazy-lock.json` | `.github/workflows/nvim-plugins.yml` + `.github/scripts/lazy_lock_bump.py` (weekly) |

Details that matter when editing this machinery:

- **Renovate finds pins only via a `# renovate: datasource=... depName=...` comment on the line directly above** the `key = "version"` line. `advisory_check.py` uses the identical regex, so a pin without that comment is invisible to both.
- **The commit-pin bumpers don't trust commit dates.** They record when they first saw each candidate (`.github/git-pin-candidates.json`, `.github/nvim-plugin-candidates.json`), and adopt one only after 7 days and after GitHub confirms it's on the branch. Those JSON files are workflow state: don't edit them by hand.
- **`.github/nvim-plugin-repos.json` maps every Neovim plugin to its real GitHub repo.** It isn't a list of overrides; `lazy_lock_bump.py` and `advisory_check.py` check plugins against it.
- **`nvim-plugins.yml` has three jobs on purpose, and the split is a security boundary:**
  - `trusted` reads the plugin list at the locked commits;
  - `resolve` runs the updated plugins' code, with no token;
  - `bump` runs no plugin code and is the only job that can push.

  Keep that separation.
- `.github/workflows/security-check.yml` runs `advisory_check.py`: `changed` mode gates every `renovate/**` branch, and `audit` mode runs weekly. `.github/security-reviewed.json` records advisories already reviewed.
- GitHub Actions are pinned to commit SHAs (Renovate's `helpers:pinGitHubActionDigests`).

## chezmoi layout

- Source names follow chezmoi's attribute prefixes: `dot_`, `private_`, `executable_`, `symlink_`, `.tmpl`. Templates branch on `.chezmoi.os` (darwin vs Linux) and occasionally `.chezmoi.hostname`.
- `.chezmoi.toml.tmpl` prompts once for name, GitHub username/email and GPG key; templates read them as `.name`, `.github_email` and so on.
- `.chezmoiignore` keeps repo-only files from being deployed (`README.md`, `install.sh`, `renovate.json`, `.github`, `nvim`) and skips macOS-only files elsewhere. Add any new repo-only file there.
- `run_onchange_after_*.sh.tmpl` scripts re-run when their rendered content changes. They embed `sha256sum` of the files they depend on, via `include`, so that editing those files triggers a re-run. When a script starts depending on a new file, add its hash the same way.
  - `install-cli-tools`: proto and all pinned tools, the Rust toolchain and components; on macOS also brew formulas.
  - `zi-pins`: checks out zi plugins at their `[git_pins]` commits.
  - `chezmoi-version`: atomically replaces `~/.local/bin/chezmoi` with the pinned version.
- `run_after_iterm2-settings.sh.tmpl` (macOS) runs on *every* apply, on purpose. iTerm2 overwrites its prefs while running, so the profile fix (`iterm2-default-profile --ensure`) can only happen while it's closed, and apply usually runs inside it. As a run_onchange script it exited 0 without finishing, so chezmoi never re-ran it. It's a no-op once set up; if iTerm2 is open, it leaves a detached waiter that fixes things when iTerm2 quits. A run_onchange script must exit non-zero if it didn't do its job.
- `.chezmoiexternal.toml.tmpl` pulls Oh my tmux! and the navi cheat sheets as archives at `[git_pins]` commits.
- **Adding a proto tool proto doesn't know natively:**
  1. Write a TOML plugin in `dot_proto/tool-plugins/<tool>.toml`, with checksum verification where the release publishes checksums. See `sesh.toml`.
  2. Register it under `[plugins]` in `dot_prototools.tmpl`.
  3. Add its version pin with a `# renovate:` comment.
- `update-all` (alias in `dot_zshrc.tmpl`) runs `chezmoi update`, the OS package manager, `proto install` and `nvim --headless "+Lazy! restore" +qa`.

## Neovim (`nvim/`)

- **Not deployed by chezmoi.** `~/.config/nvim` is a symlink into this directory (`dot_config/symlink_nvim.tmpl`), so edits take effect immediately and lazy.nvim writes `lazy-lock.json` straight into the repo.
- Load order (`lua/lazy_setup.lua`): AstroNvim (`version = "^6"`), then `lua/community.lua` (AstroCommunity imports: language packs, colorscheme, motions…), then `lua/plugins/*.lua` (overrides and additions), then `lua/polish.lua`. `checker` is off on purpose, so lazy doesn't nag about updates.
- `lua/plugins/plugin-sources.lua` points plugins whose repo has moved at their current URL (`optional = true`, so it only changes where they come from, without adding them). Keep it in step with `nvim-plugin-repos.json`.
- `lua/plugins/user.lua` is the inactive AstroNvim template example (`if true then return {} end`).
- Lua style: `nvim/.stylua.toml` (2 spaces, 120 columns, no call parentheses) and `nvim/selene.toml` (`std = "neovim"`).
- **Tutorials (`:Tutor my-00-start` …):** edit `tutor/src/*.tutor.src`, then run the build, which regenerates `tutor/en/*.tutor` and `*.tutor.json`. Never edit `tutor/en/` directly. Exercise lines are written `{{start text ||| expected text}}`.

## Checking changes

There's no test suite. Verify with:

```sh
chezmoi diff                                   # what apply would change in $HOME
chezmoi apply --dry-run --verbose              # same, plus which run_onchange scripts would fire
chezmoi execute-template < some_file.tmpl      # render one template
chezmoi doctor
python3 nvim/tutor/build.py                    # after editing tutor/src/*.tutor.src
(cd nvim && stylua --check . && selene .)      # run from nvim/ so they find its config; Mason installs both (~/.local/share/nvim/mason/bin)
shellcheck install.sh .github/scripts/*.sh
python3 -m py_compile .github/scripts/*.py
nvim --headless "+Lazy! restore" +qa           # Neovim loads plugins at the locked commits
```

`chezmoi apply` really changes the home directory and can run the install scripts (brew, proto, rustup). Use the `--dry-run` form unless applying is the point.

## Conventions

- Commit subjects are short and lower-case, scoped by area: `nvim-plugins: …`, `advisory_check: …`, `zsh: …`, `README: …`. The bots use `nvim: plugin bumps (first seen 7+ days ago)` and `git pins: bumps (first seen 7+ days ago)`.
- Comments explain *why* (security reasoning, platform quirks, past incidents). Match that density when editing scripts and workflows.
- mise is deliberately not used (it was removed): proto plus direnv only. `install.sh` offers to remove mise, Linux Homebrew, snap Neovim and stray chezmoi copies.
