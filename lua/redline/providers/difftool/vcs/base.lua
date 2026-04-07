local detect = require("redline.providers.difftool.detect")

local M = {}

local function side_paths(ctx, side)
  if side == "left" then
    return ctx.left_path, ctx.right_path
  end
  return ctx.right_path, ctx.left_path
end

local function side_rels(ctx, side)
  if side == "left" then
    return ctx.left_rel, ctx.right_rel
  end
  return ctx.right_rel, ctx.left_rel
end

function M.make_side(path, relpath, rev, rev_kind, display)
  return {
    path = path,
    relpath = relpath,
    rev = rev,
    rev_kind = rev_kind,
    display = display or rev,
  }
end

function M.make_meta(ctx, spec)
  local primary_path, peer_path = side_paths(ctx, ctx.side)
  local primary_rel, peer_rel = side_rels(ctx, ctx.side)

  return {
    vcs = ctx.detection.vcs,
    repo_root = ctx.detection.repo_root,
    packet_key = ctx.detection.packet_key,
    confidence = spec.confidence or "low",
    notes = spec.notes or {},
    current = M.make_side(
      primary_path,
      primary_rel or detect.relative_path(primary_path, ctx.detection.repo_root),
      spec.current_rev,
      spec.current_rev_kind,
      spec.current_display
    ),
    peer = M.make_side(
      peer_path,
      peer_rel or detect.relative_path(peer_path, ctx.detection.repo_root),
      spec.peer_rev,
      spec.peer_rev_kind,
      spec.peer_display
    ),
  }
end

return M
