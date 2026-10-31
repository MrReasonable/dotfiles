-- Snacks overrides
-- ----------------
-- AstroNvim turns Snacks.image on by default, but it draws images with the
-- kitty graphics protocol, which only kitty, WezTerm and Ghostty speak. This
-- setup runs in iTerm2 (inside tmux), so it can never render an image there;
-- leaving it on only produces `:checkhealth` errors (no kitty graphics, no
-- `gs`, no `tectonic`/`pdflatex`, missing latex/typst/vue parsers). Re-enable
-- if you ever move to a kitty-protocol terminal.

---@type LazySpec
return {
  "folke/snacks.nvim",
  opts = {
    image = { enabled = false },
  },
}
