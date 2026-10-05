#!/usr/bin/env bash
# Resolve Neovim plugin updates (step 1 of .github/workflows/nvim-plugins.yml).
#
#   nvim-plugins-update.sh OUT_DIR
#
# Runs the repo's Neovim config headlessly in throwaway XDG folders: lazy
# installs from the current lock, then `:Lazy! update` picks the newest versions
# the plugin specs allow. Writes OUT_DIR/lazy-lock.json (lazy's result) and
# OUT_DIR/info.json (each plugin's URL). This step runs plugins' own code
# (install/build hooks), so the workflow gives it no token and no write access;
# lazy_lock_bump.py (step 2) decides what the repo's lock actually becomes.
set -euo pipefail

out=$(cd "$1" && pwd)
repo=$(cd "$(dirname "$0")/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work" 2>/dev/null || true' EXIT
export XDG_CONFIG_HOME="$work/config" XDG_DATA_HOME="$work/data" \
  XDG_STATE_HOME="$work/state" XDG_CACHE_HOME="$work/cache"
mkdir -p "$XDG_CONFIG_HOME"
cp -R "$repo/nvim" "$XDG_CONFIG_HOME/nvim"

# Install at the locked commits, then update within the specs. Plugin build
# steps (parsers, binaries) may fail here without a full toolchain; only the
# resulting lock matters.
timeout 900 nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 || true
timeout 900 nvim --headless "+Lazy! update" +qa >/dev/null 2>&1 || true

timeout 120 nvim --headless "+lua
  local out = {}
  for name, p in pairs(require('lazy.core.config').plugins) do out[name] = { url = p.url } end
  vim.fn.writefile({ vim.json.encode(out) }, '$out/info.json')
" +qa >/dev/null 2>&1
cp "$XDG_CONFIG_HOME/nvim/lazy-lock.json" "$out/lazy-lock.json"
