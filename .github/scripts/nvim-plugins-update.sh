#!/usr/bin/env bash
# Update nvim/lazy-lock.json to plugin commits at least 7 days old (run weekly by
# .github/workflows/nvim-plugins.yml; also runnable locally from the repo root).
#
# Runs the repo's Neovim config headlessly in throwaway XDG folders, so nothing
# of yours is touched: lazy installs from the current lock, `:Lazy! update`
# picks the newest versions the plugin specs allow, and lazy_lock_bump.py keeps
# only what's old enough. Needs nvim on PATH and GITHUB_TOKEN.
set -euo pipefail

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

# Each plugin's URL, and whether it follows a release tag (vs a branch).
timeout 120 nvim --headless "+lua
  local cfg = require('lazy.core.config')
  local out = {}
  for name, p in pairs(cfg.plugins) do
    local v = p.version
    if v == nil then v = cfg.options.defaults.version end
    out[name] = { url = p.url, versioned = (v ~= nil and v ~= false) or p.tag ~= nil or p.commit ~= nil }
  end
  vim.fn.writefile({ vim.json.encode(out) }, '$work/info.json')
" +qa >/dev/null 2>&1

python3 "$repo/.github/scripts/lazy_lock_bump.py" \
  "$repo/nvim/lazy-lock.json" "$XDG_CONFIG_HOME/nvim/lazy-lock.json" "$work/info.json"
