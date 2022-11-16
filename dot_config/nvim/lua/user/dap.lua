local status_ok, dap = pcall(require, 'dap')
if not status_ok then
  vim.notify("unable to load dap")
end

local go_dap_status_ok, _ = pcall(require, 'dap-go')
if not status_ok then
  vim.notify('unable to load dap-go')
end

