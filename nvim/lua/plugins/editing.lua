-- Surround: add, change and delete the quotes, brackets or tags around text.
--
--   ys{motion}{char}  add       ysiw"  wraps the word in "quotes"
--   yss{char}         add around the whole line
--   ds{char}          delete    ds(    removes the brackets round the cursor
--   cs{old}{new}      change    cs'"   turns 'this' into "this"
--   gs{char}          (visual)  wrap the selection
--
-- nvim-surround rather than mini.surround because mini's keys start with `s`,
-- which flash uses for jumping. Its usual visual key `S` is flash's
-- Treesitter select here, so visual surround moves to `gs`.
-- Opening brackets add a space inside: ysiw( gives "( word )", ysiw) "(word)".

---@type LazySpec
return {
  {
    "kylechui/nvim-surround",
    version = "^3",
    event = "User AstroFile",
    opts = {
      keymaps = {
        visual = "gs",
        visual_line = "gS",
      },
    },
  },

  -- Vitest support for neotest (<Leader>T…). The TypeScript pack only brings
  -- Jest; each adapter only claims test files in projects that use its runner.
  {
    "nvim-neotest/neotest",
    optional = true,
    dependencies = { { "marilari88/neotest-vitest", config = function() end } },
    opts = function(_, opts)
      if not opts.adapters then opts.adapters = {} end
      table.insert(opts.adapters, require "neotest-vitest" {})
    end,
  },

  -- sqls.nvim (SQL commands like :SqlsExecuteQuery) now hooks into Neovim's
  -- own LSP config (its lsp/sqls.lua, whose on_attach adds the commands), but
  -- AstroCommunity's SQL pack still calls the old require("sqls").on_attach,
  -- which errored on every SQL file, and sets its own on_attach, which hid the
  -- plugin's. Drop both (keeping the pack's "no formatting with sqls", via
  -- AstroLSP's setting; sqlfluff formats), and load the plugin at startup
  -- (it's tiny) so its lsp/ config is there before sqls starts.
  { "nanotee/sqls.nvim", lazy = false },
  { "AstroNvim/astrocore", opts = { autocmds = { sqls_attach = false } } },
  {
    "AstroNvim/astrolsp",
    opts = function(_, opts)
      if opts.config and opts.config.sqls then opts.config.sqls.on_attach = nil end
      opts.formatting = opts.formatting or {}
      opts.formatting.disabled = opts.formatting.disabled or {}
      table.insert(opts.formatting.disabled, "sqls")
    end,
  },
}
