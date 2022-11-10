local status_ok, whitespace = pcall(require, "whitespace-nvim")
if not status_ok then
  vim.notify("unable to load whitespace-nvim")
  return
end

whitespace.setup()

vim.api.nvim_create_autocmd("BufWritePre", {
  desc = "Trim whitespace on save",
  callback = whitespace.trim
})


