-- :Practice opens a fresh copy of the practice project used by the my-*
-- tutorials (:Tutor my-00-start), in a new tab with its own working
-- directory, so your real projects are never touched. Run it again any time
-- to reset everything.
--
-- The copy lives in Neovim's cache folder. It's made into a git repo with one
-- commit, then a change is added on top, so the git lesson has something to
-- stage, preview and undo.

local function practice()
  local src = vim.fn.stdpath "config" .. "/tutor/practice"
  local dst = vim.fn.stdpath "cache" .. "/practice"
  vim.fn.delete(dst, "rf")
  vim.fn.mkdir(vim.fn.fnamemodify(dst, ":h"), "p")
  local function run(cmd)
    local res = vim.system(cmd, { cwd = dst, text = true }):wait()
    if res.code ~= 0 then error(table.concat(cmd, " ") .. ": " .. (res.stderr or "")) end
  end
  vim.system({ "cp", "-R", src, dst }):wait()
  run { "git", "init", "-q", "-b", "main" }
  run { "git", "add", "-A" }
  run {
    "git", "-c", "user.name=Practice", "-c", "user.email=practice@example.invalid",
    "-c", "commit.gpgSign=false", "commit", "-q", "-m", "Practice project",
  }
  -- the uncommitted change for the git lesson
  local index = dst .. "/src/index.ts"
  local lines = vim.fn.readfile(index)
  table.insert(lines, 5, 'cart.add({ sku: "BISCUIT-3", qty: 4, price: { pence: 199, currency: "GBP" } });')
  vim.fn.writefile(lines, index)

  vim.cmd.tabnew()
  vim.cmd.tcd(vim.fn.fnameescape(dst))
  vim.cmd.edit "src/cart.ts"
  vim.notify("Practice project ready in a new tab (]t / [t to switch tabs)", vim.log.levels.INFO)
end

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    commands = {
      Practice = { practice, desc = "Fresh copy of the my-* tutorial practice project, in a new tab" },
    },
  },
}
