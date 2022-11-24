local status_ok, notify = pcall(require, 'notify')

if not status_ok then
  vim.notify("Unable to load notification plugin")
  return
end

vim.notify = notify
