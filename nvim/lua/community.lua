-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.
-- Browse what's available: https://github.com/AstroNvim/astrocommunity

---@type LazySpec
return {
  "AstroNvim/astrocommunity",

  -- Languages: each pack wires up the language server, formatter, linter,
  -- treesitter parser and debugger (installed by Mason on first use).
  { import = "astrocommunity.pack.typescript" }, -- vtsls, eslint, prettier/biome
  { import = "astrocommunity.pack.tailwindcss" },
  { import = "astrocommunity.pack.json" },
  { import = "astrocommunity.pack.yaml" },
  { import = "astrocommunity.pack.markdown" },
  { import = "astrocommunity.pack.docker" },
  { import = "astrocommunity.pack.toml" },
  { import = "astrocommunity.pack.just" },
  { import = "astrocommunity.pack.lua" },
  { import = "astrocommunity.pack.rust" }, -- rustaceanvim, crates.nvim, codelldb
  { import = "astrocommunity.pack.go" }, -- gopls, gofumpt, delve
  -- Python: basedpyright for types, ruff for lint + format (not black/isort)
  { import = "astrocommunity.pack.python.base" },
  { import = "astrocommunity.pack.python.basedpyright" },
  { import = "astrocommunity.pack.python.ruff" },

  -- Claude Code inside Neovim (needs the `claude` CLI): <Leader>A…
  { import = "astrocommunity.ai.claudecode-nvim" },

  -- Getting around
  { import = "astrocommunity.motion.flash-nvim" }, -- `s` + 2 chars jumps anywhere on screen
  { import = "astrocommunity.motion.harpoon" }, -- pin your working files to single keys

  -- Git, diagnostics, tasks and tests
  { import = "astrocommunity.git.diffview-nvim" }, -- side-by-side diffs, file history, merge conflicts
  { import = "astrocommunity.diagnostics.trouble-nvim" }, -- project-wide problems list
  { import = "astrocommunity.code-runner.overseer-nvim" }, -- run just/npm/cargo tasks
  { import = "astrocommunity.test.neotest" }, -- run tests next to the code

  -- Learning aid: hints for the motions available from the cursor (toggle
  -- with :Precognition toggle)
  { import = "astrocommunity.workflow.precognition-nvim" },
  -- Habit coach: suggests faster motions (hint mode, configured in
  -- lua/plugins/hardtime.lua); `:Hardtime report` lists your top habits
  { import = "astrocommunity.workflow.hardtime-nvim" },
}
