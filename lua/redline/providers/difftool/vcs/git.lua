local base = require("redline.providers.difftool.vcs.base")
local detect = require("redline.providers.difftool.detect")
local util = require("redline.providers.difftool.vcs.util")

local M = {
  name = "git",
}

local function repo_relpath(ctx)
  if detect.is_inside_root(ctx.right_path, ctx.detection.repo_root) and ctx.right_rel then
    return ctx.right_rel
  end
  if detect.is_inside_root(ctx.left_path, ctx.detection.repo_root) and ctx.left_rel then
    return ctx.left_rel
  end
  return ctx.right_rel or ctx.left_rel
end

function M.diff_for_path(ctx)
  local relpath = repo_relpath(ctx)
  if not relpath or relpath == "" or relpath:sub(1, 1) == "/" then
    return nil
  end
  return util.run({ "git", "diff", "--no-ext-diff", "--", relpath }, ctx.detection.repo_root)
end

local function head_blob(repo_root, relpath)
  if not relpath or relpath == "" then
    return nil
  end
  local out = util.run({ "git", "ls-tree", "HEAD", "--", relpath }, repo_root)
  if not out then
    return nil
  end
  return out:match("^%d+ blob (%x+)")
end

function M.resolve_session(ctx)
  local current_in_repo = detect.is_inside_root(ctx.current_path, ctx.detection.repo_root)
  local peer_in_repo = detect.is_inside_root(ctx.peer_path, ctx.detection.repo_root)
  local head = util.run({ "git", "rev-parse", "HEAD" }, ctx.detection.repo_root)
  local current_hash = current_in_repo and util.file_hash(ctx.current_path) or nil
  local peer_hash = peer_in_repo and util.file_hash(ctx.peer_path) or nil

  local function worktree_spec(hash)
    local short = util.shorten_hash(hash)
    return {
      rev = hash or "WORKTREE",
      kind = hash and "blob" or "working-copy",
      display = short and ("WORKTREE " .. short) or "WORKTREE",
    }
  end

  local function head_spec(relpath)
    local short = util.shorten_hash(head)
    local blob = head_blob(ctx.detection.repo_root, relpath)
    local blob_short = util.shorten_hash(blob)
    local display = short and ("HEAD " .. short) or "HEAD"
    if blob_short then
      display = display .. " blob " .. blob_short
    end
    return {
      rev = head or "HEAD",
      kind = "commit",
      display = display,
    }
  end

  if current_in_repo and not peer_in_repo then
    local current = worktree_spec(current_hash)
    local peer = head_spec(repo_relpath(ctx))
    return base.make_meta(ctx, {
      confidence = "medium",
      current_rev = current.rev,
      current_rev_kind = current.kind,
      current_display = current.display,
      peer_rev = peer.rev,
      peer_rev_kind = peer.kind,
      peer_display = peer.display,
    })
  end

  if peer_in_repo and not current_in_repo then
    local current = head_spec(repo_relpath(ctx))
    local peer = worktree_spec(peer_hash)
    return base.make_meta(ctx, {
      confidence = "medium",
      current_rev = current.rev,
      current_rev_kind = current.kind,
      current_display = current.display,
      peer_rev = peer.rev,
      peer_rev_kind = peer.kind,
      peer_display = peer.display,
    })
  end

  if ctx.side == "right" then
    local current = worktree_spec(current_hash)
    local peer = head_spec(repo_relpath(ctx))
    return base.make_meta(ctx, {
      confidence = "low",
      current_rev = current.rev,
      current_rev_kind = current.kind,
      current_display = current.display,
      peer_rev = peer.rev,
      peer_rev_kind = peer.kind,
      peer_display = peer.display,
    })
  end

  local current = head_spec(repo_relpath(ctx))
  local peer = worktree_spec(peer_hash)
  return base.make_meta(ctx, {
    confidence = "low",
    current_rev = current.rev,
    current_rev_kind = current.kind,
    current_display = current.display,
    peer_rev = peer.rev,
    peer_rev_kind = peer.kind,
    peer_display = peer.display,
  })
end

return M
