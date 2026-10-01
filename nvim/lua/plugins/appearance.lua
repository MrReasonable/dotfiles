-- Colours: TokyoNight, following macOS light/dark mode, to match iTerm2, the
-- tmux status bar and fzf (all TokyoNight Storm in dark mode, Day in light).
--
-- auto-dark-mode.nvim checks the system appearance every few seconds (it asks
-- macOS directly, so tmux in between doesn't matter) and flips 'background';
-- the plain "tokyonight" colorscheme then shows `style` (dark) or
-- `light_style` (light) to match.

---@type LazySpec
return {
  {
    "AstroNvim/astroui",
    ---@type AstroUIOpts
    opts = { colorscheme = "tokyonight" },
  },
  {
    "folke/tokyonight.nvim",
    opts = {
      style = "storm", -- dark mode
      light_style = "day", -- light mode
      on_highlights = function(hl, c)
        -- line numbers default to fg_gutter, which is faint in both styles;
        -- dark5 is TokyoNight's own slightly brighter grey
        hl.LineNr = { fg = c.dark5 }
        hl.LineNrAbove = { fg = c.dark5 }
        hl.LineNrBelow = { fg = c.dark5 }
      end,
    },
  },
  {
    "f-person/auto-dark-mode.nvim",
    lazy = false,
    opts = {
      update_interval = 3000, -- ms between checks of the system appearance
      fallback = "dark", -- used if the appearance can't be read
      set_dark_mode = function() vim.o.background = "dark" end,
      set_light_mode = function() vim.o.background = "light" end,
    },
  },
}
