#!/usr/bin/env bash
# Neovim plugin data for .github/workflows/nvim-plugins.yml.
#
#   nvim-plugins-update.sh trusted OUT_DIR   plugin names + URLs (OUT_DIR/info.json),
#                                            read from the config at the LOCKED
#                                            commits: versions your machines run
#   nvim-plugins-update.sh resolve OUT_DIR   lazy's lock after `:Lazy! update`
#                                            (OUT_DIR/lazy-lock.json): runs the
#                                            UPDATED plugins' own code, so the
#                                            workflow trusts only its commits
#
# Runs the repo's Neovim config headlessly in throwaway XDG folders. Plugin
# build steps may fail without a full toolchain; only the data matters.
set -euo pipefail

mode=$1
out=$(cd "$2" && pwd)
repo=$(cd "$(dirname "$0")/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work" 2>/dev/null || true' EXIT
export XDG_CONFIG_HOME="$work/config" XDG_DATA_HOME="$work/data" \
  XDG_STATE_HOME="$work/state" XDG_CACHE_HOME="$work/cache"
mkdir -p "$XDG_CONFIG_HOME"
cp -R "$repo/nvim" "$XDG_CONFIG_HOME/nvim"

timeout 900 nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 || true

case "$mode" in
  trusted)
    timeout 120 nvim --headless "+lua
      local out = {}
      for name, p in pairs(require('lazy.core.config').plugins) do out[name] = { url = p.url } end
      vim.fn.writefile({ vim.json.encode(out) }, '$out/info.json')
    " +qa >/dev/null 2>&1
    test -s "$out/info.json"
    ;;
  resolve)
    timeout 900 nvim --headless "+Lazy! update" +qa >/dev/null 2>&1 || true
    cp "$XDG_CONFIG_HOME/nvim/lazy-lock.json" "$out/lazy-lock.json"
    ;;
  *) echo "usage: $0 trusted|resolve OUT_DIR" >&2; exit 64 ;;
esac
