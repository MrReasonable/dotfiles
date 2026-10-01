-- Follow macOS light/dark mode, and make line numbers readable.
--
-- auto-dark-mode.nvim checks the system appearance every few seconds (it asks
-- macOS directly, so tmux in between doesn't matter) and flips 'background';
-- astrotheme then shows astrolight or astrodark to match. Loading the plain
-- "astrotheme" colorscheme (instead of AstroNvim's default "astrodark") is
-- what lets it pick the palette from 'background'.

---@type LazySpec
return {
  {
    "AstroNvim/astroui",
    ---@type AstroUIOpts
    opts = { colorscheme = "astrotheme" },
  },
  {
    "AstroNvim/astrotheme",
    opts = {
      highlights = {
        -- astrodark's line numbers (#3a3e47) all but vanish on its near-black
        -- background, especially over a translucent terminal...
        astrodark = {
          LineNr = { fg = "#7a7f8a" },
        },
        -- and astrolight's (#b5b9bd) are just as faint on its near-white one
        astrolight = {
          LineNr = { fg = "#7b8189" },
        },
      },
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
