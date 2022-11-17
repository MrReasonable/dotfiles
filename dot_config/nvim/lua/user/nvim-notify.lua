local status_ok, notify = pcall(require, 'notify')

if !status_ok then
  vim.notify("Unable to load notification plugin")
  return
end

vim.notify = notify
