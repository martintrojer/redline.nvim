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

function M.repo_relpath(ctx)
  if detect.is_inside_root(ctx.right_path, ctx.detection.repo_root) and ctx.right_rel then
    return ctx.right_rel
  end
  if detect.is_inside_root(ctx.left_path, ctx.detection.repo_root) and ctx.left_rel then
    return ctx.left_rel
  end
  return ctx.right_rel or ctx.left_rel
end

function M.make_side(path, relpath, spec)
  return {
    path = path,
    relpath = relpath,
    rev = spec.rev,
    rev_kind = spec.kind,
    display = spec.display or spec.rev,
  }
end

function M.make_meta(ctx, current_spec, peer_spec, confidence)
  local primary_path, peer_path = side_paths(ctx, ctx.side)
  local primary_rel, peer_rel = side_rels(ctx, ctx.side)

  return {
    vcs = ctx.detection.vcs,
    repo_root = ctx.detection.repo_root,
    packet_key = ctx.detection.packet_key,
    confidence = confidence or "low",
    current = M.make_side(
      primary_path,
      primary_rel or detect.relative_path(primary_path, ctx.detection.repo_root),
      current_spec
    ),
    peer = M.make_side(
      peer_path,
      peer_rel or detect.relative_path(peer_path, ctx.detection.repo_root),
      peer_spec
    ),
  }
end

function M.resolve_sides(ctx, working_spec, committed_spec)
  local current_in = detect.is_inside_root(ctx.current_path, ctx.detection.repo_root)
  local peer_in = detect.is_inside_root(ctx.peer_path, ctx.detection.repo_root)

  if current_in and not peer_in then
    return M.make_meta(ctx, working_spec, committed_spec, "medium")
  end
  if peer_in and not current_in then
    return M.make_meta(ctx, committed_spec, working_spec, "medium")
  end
  if ctx.side == "right" then
    return M.make_meta(ctx, working_spec, committed_spec, "low")
  end
  return M.make_meta(ctx, committed_spec, working_spec, "low")
end

return M
