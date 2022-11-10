local status_ok, tokyonight = pcall(require, "tokyonight")

if not status_ok then
  vim.notify("unable to load tokyonight plugin")
end

local M = {}

M.setup = function(theme)
    tokyonight.setup({
      style = theme,
      transparent = true,
      sidebars = { "qf", "help" },
      dim_inactive = true,
      lualine_bold = true,
    })
end

return M
