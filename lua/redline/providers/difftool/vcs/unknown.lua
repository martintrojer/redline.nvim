local base = require("redline.providers.difftool.vcs.base")

local M = {
  name = "unknown",
}

function M.resolve_session(ctx)
  local current_display = ctx.side == "right" and "RIGHT" or "LEFT"
  local peer_display = ctx.side == "right" and "LEFT" or "RIGHT"

  return base.make_meta(
    ctx,
    { rev = "unknown", kind = "unknown", display = current_display },
    { rev = "unknown", kind = "unknown", display = peer_display },
    "low"
  )
end

return M
