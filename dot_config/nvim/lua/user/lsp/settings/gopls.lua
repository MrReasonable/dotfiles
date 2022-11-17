local status_ok, go = pcall(require, 'go')
if status_ok then
  go.config.update_tool('quicktype', function(tool)
    tool.pkg_mgr = 'pnpm'
  end)
end

return {
  experimentalPostfixCompletions = true,
  analyses = {
    unusedParams = true,
    shadow = true,
  },
  staticcheck = true,
}
