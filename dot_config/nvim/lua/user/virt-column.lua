local status_ok, v_column = pcall(require, "virt-column")

if not status_ok then
  vim.notify("unable to load virt-column")
  return
end

v_column.setup()
