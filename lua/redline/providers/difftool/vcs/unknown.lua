local base = require("redline.providers.difftool.vcs.base")

local M = {
  name = "unknown",
}

function M.resolve_session(ctx)
  local current_display = ctx.side == "right" and "RIGHT" or "LEFT"
  local peer_display = ctx.side == "right" and "LEFT" or "RIGHT"

  return base.make_meta(ctx, {
    confidence = "low",
    current_rev = "unknown",
    current_rev_kind = "unknown",
    current_display = current_display,
    peer_rev = "unknown",
    peer_rev_kind = "unknown",
    peer_display = peer_display,
  })
end

return M
