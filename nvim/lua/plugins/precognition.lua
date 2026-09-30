-- precognition.nvim (imported in community.lua): a virtual line under the
-- cursor line marking where ^ b w e $ % would jump. `:Precognition toggle`
-- hides it; `:Precognition peek` shows it once while hidden.

---@type LazySpec
return {
  "tris203/precognition.nvim",
  opts = {
    -- The F/T hints marked every character reachable with F<char>/T<char>,
    -- turning the hint line into a wall of "FTFFTFF..."; keep just motions.
    targetedMotionHints = { enabled = false },
    -- Don't reserve an empty hint line when there's nothing to show.
    showBlankVirtLine = false,
  },
}
