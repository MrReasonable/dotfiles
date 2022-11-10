return {
	settings = {

		Lua = {
      telemetry = { enable = false },
      runtime = {
        version = "LuaJIT",
        special = {
          reload = "require"
        },
      },
      completion = {
        callSnippet = "Replace"
      },
			diagnostics = {
				globals = { "vim", "lvim", "packer_plugins", "reload" },
			},
			workspace = {
				library = {
					[vim.fn.expand("$VIMRUNTIME/lua")] = true,
					[vim.fn.stdpath("config") .. "/lua"] = true,
          vim.api.nvim_get_runtime_file("", true),
				},
			},
		},
	},
}
