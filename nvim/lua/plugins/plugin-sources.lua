-- Plugins whose GitHub repo has moved: point at the current address directly,
-- rather than relying on GitHub's redirect from the old one. `optional`: this
-- only changes where a plugin comes from; it doesn't add the plugin by itself.
--
-- clangd_extensions.nvim: its author renamed their account from p00f to
-- dchinmay2, and a *different* account has since registered "p00f". If that
-- account created a repo with the same name, the old address would quietly
-- point at it (repo-jacking). Same code, same commits at the new address.
-- mini.ai and smart-splits.nvim moved into organisations, same maintainers.
--
-- The weekly plugin bump pins each plugin's repo in
-- .github/nvim-plugin-repos.json; keep that in step with these.

---@type LazySpec
return {
  { "p00f/clangd_extensions.nvim", optional = true, url = "https://github.com/dchinmay2/clangd_extensions.nvim.git" },
  { "echasnovski/mini.ai", optional = true, url = "https://github.com/nvim-mini/mini.ai.git" },
  { "mrjones2014/smart-splits.nvim", optional = true, url = "https://github.com/smart-splits-nvim/smart-splits.nvim.git" },
}
