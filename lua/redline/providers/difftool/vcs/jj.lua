local base = require("redline.providers.difftool.vcs.base")
local detect = require("redline.providers.difftool.detect")
local util = require("redline.providers.difftool.vcs.util")

local M = {
  name = "jj",
}

function M.diff_for_path(ctx)
  local relpath = ctx.right_rel or ctx.left_rel
  if not relpath or relpath == "" or relpath:sub(1, 1) == "/" then
    return nil
  end
  return util.run({ "jj", "diff", "--git", "--", relpath }, ctx.detection.repo_root)
end

local function rev_spec(repo_root, revset)
  local out = util.run({
    "jj",
    "log",
    "-r",
    revset,
    "-T",
    'change_id.short() ++ " " ++ commit_id.short() ++ "\n"',
    "--no-graph",
    "-n",
    "1",
  }, repo_root)
  if not out then
    return {
      rev = revset,
      kind = "unknown",
      display = revset,
    }
  end

  local change_id, commit_id = out:match("^(%S+)%s+(%S+)$")
  if not change_id or not commit_id then
    return {
      rev = revset,
      kind = "unknown",
      display = revset,
    }
  end

  return {
    rev = commit_id,
    kind = "commit",
    display = string.format("%s %s %s", revset, change_id, commit_id),
  }
end

function M.resolve_session(ctx)
  local current_in_repo = detect.is_inside_root(ctx.current_path, ctx.detection.repo_root)
  local peer_in_repo = detect.is_inside_root(ctx.peer_path, ctx.detection.repo_root)
  local at = rev_spec(ctx.detection.repo_root, "@")
  local parent = rev_spec(ctx.detection.repo_root, "@-")

  if current_in_repo and not peer_in_repo then
    return base.make_meta(ctx, {
      confidence = "medium",
      current_rev = at.rev,
      current_rev_kind = at.kind,
      current_display = at.display,
      peer_rev = parent.rev,
      peer_rev_kind = parent.kind,
      peer_display = parent.display,
    })
  end

  if peer_in_repo and not current_in_repo then
    return base.make_meta(ctx, {
      confidence = "medium",
      current_rev = parent.rev,
      current_rev_kind = parent.kind,
      current_display = parent.display,
      peer_rev = at.rev,
      peer_rev_kind = at.kind,
      peer_display = at.display,
    })
  end

  if ctx.side == "right" then
    return base.make_meta(ctx, {
      confidence = "low",
      current_rev = at.rev,
      current_rev_kind = at.kind,
      current_display = at.display,
      peer_rev = parent.rev,
      peer_rev_kind = parent.kind,
      peer_display = parent.display,
    })
  end

  return base.make_meta(ctx, {
    confidence = "low",
    current_rev = parent.rev,
    current_rev_kind = parent.kind,
    current_display = parent.display,
    peer_rev = at.rev,
    peer_rev_kind = at.kind,
    peer_display = at.display,
  })
end

return M
