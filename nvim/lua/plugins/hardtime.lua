-- hardtime.nvim (imported in community.lua), set up as a coach, not a jailer:
-- it only *suggests* faster motions ("Use 10j instead of jjjj…") and never
-- blocks a key. `:Hardtime report` lists your most frequent hints;
-- `:Hardtime toggle` turns it off. For the strict version, set
-- restriction_mode = "block" (repeated hjkl beyond max_count get ignored).

---@type LazySpec
return {
  "m4xshen/hardtime.nvim",
  opts = {
    restriction_mode = "hint", -- default "block" swallows the 4th j/k/h/l within max_time
    disable_mouse = false, -- keep the mouse (tmux has mouse mode on)
    -- the plugin disables arrow keys and the community module adds
    -- Insert/Home/End/PageUp/PageDown (even in insert mode); allow them all
    disabled_keys = {
      ["<Up>"] = false,
      ["<Down>"] = false,
      ["<Left>"] = false,
      ["<Right>"] = false,
      ["<Insert>"] = false,
      ["<Home>"] = false,
      ["<End>"] = false,
      ["<PageUp>"] = false,
      ["<PageDown>"] = false,
    },
  },
}
