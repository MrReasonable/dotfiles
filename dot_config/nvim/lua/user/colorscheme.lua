local colorscheme = "tokyonight"

local scheme_status_ok, scheme_settings = pcall(require, "user.config." .. colorscheme)

ChangeBackground = function(theme)
	if scheme_status_ok then
		scheme_settings.setup(theme)
	end

	local status_ok, _ = pcall(vim.cmd, "colorscheme " .. colorscheme)
	if not status_ok then
		vim.notify("unable to set colorscheme " .. colorscheme)
		return
	end

	pcall(vim.cmd, "redraw!")
	pcall(vim.cmd, ":NvimTreeToggle")
	pcall(vim.cmd, ":NvimTreeToggle")
end

local theme = "night"

if jit.os == "OSX" then
	if os.execute("defaults.read -g AppleInterfaceStyle") == 1 then
		theme = "day"
	end
end
vim.notify("Changing...")

ChangeBackground(theme)

vim.api.nvim_create_user_command("ChangeBackground", ":lua ChangeBackground(<f-args>)", {
	nargs = 1,
	complete = function(_, _, _)
		return { "day", "night" }
	end,
})
