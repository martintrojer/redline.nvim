local base = require("redline.providers.difftool.vcs.base")
local detect = require("redline.providers.difftool.detect")
local util = require("redline.providers.difftool.vcs.util")

local M = {
  name = "hg",
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
  return util.run({ "hg", "diff", relpath }, ctx.detection.repo_root)
end

local function manifest_file_hash(repo_root, relpath)
  if not relpath or relpath == "" then
    return nil
  end
  local out = util.run({ "hg", "manifest", "--debug", "-r", "." }, repo_root)
  if not out then
    return nil
  end
  for _, line in ipairs(vim.split(out, "\n", { plain = true })) do
    local hash, path = line:match("^(%x+)%s+%d+%s+(.+)$")
    if hash and path == relpath then
      return hash
    end
  end
  return nil
end

local function rev_spec(repo_root, revset)
  local out = util.run({
    "hg",
    "log",
    "-r",
    revset,
    "--template",
    "{rev} {node|short}\n",
  }, repo_root)
  if not out then
    return {
      rev = revset,
      kind = "unknown",
      display = revset,
    }
  end

  local revnum, node = out:match("^(%S+)%s+(%S+)$")
  if not revnum or not node then
    return {
      rev = revset,
      kind = "unknown",
      display = revset,
    }
  end

  return {
    rev = node,
    kind = "commit",
    display = string.format("%s %s", revnum, node),
  }
end

local function worktree_spec(path)
  local hash = util.file_hash(path)
  local short = util.shorten_hash(hash)
  return {
    rev = hash or "WORKTREE",
    kind = hash and "blob" or "working-copy",
    display = short and ("WORKTREE " .. short) or "WORKTREE",
  }
end

function M.resolve_session(ctx)
  local current_in_repo = detect.is_inside_root(ctx.current_path, ctx.detection.repo_root)
  local peer_in_repo = detect.is_inside_root(ctx.peer_path, ctx.detection.repo_root)
  local dot = rev_spec(ctx.detection.repo_root, ".")
  local file_hash =
    util.shorten_hash(manifest_file_hash(ctx.detection.repo_root, repo_relpath(ctx)))
  if file_hash then
    dot.display = dot.display .. " file " .. file_hash
  end

  if current_in_repo and not peer_in_repo then
    local current = worktree_spec(ctx.current_path)
    return base.make_meta(ctx, {
      confidence = "medium",
      current_rev = current.rev,
      current_rev_kind = current.kind,
      current_display = current.display,
      peer_rev = dot.rev,
      peer_rev_kind = dot.kind,
      peer_display = dot.display,
    })
  end

  if peer_in_repo and not current_in_repo then
    local peer = worktree_spec(ctx.peer_path)
    return base.make_meta(ctx, {
      confidence = "medium",
      current_rev = dot.rev,
      current_rev_kind = dot.kind,
      current_display = dot.display,
      peer_rev = peer.rev,
      peer_rev_kind = peer.kind,
      peer_display = peer.display,
    })
  end

  if ctx.side == "right" then
    local current = worktree_spec(ctx.current_path)
    return base.make_meta(ctx, {
      confidence = "low",
      current_rev = current.rev,
      current_rev_kind = current.kind,
      current_display = current.display,
      peer_rev = dot.rev,
      peer_rev_kind = dot.kind,
      peer_display = dot.display,
    })
  end

  local peer = worktree_spec(ctx.peer_path)
  return base.make_meta(ctx, {
    confidence = "low",
    current_rev = dot.rev,
    current_rev_kind = dot.kind,
    current_display = dot.display,
    peer_rev = peer.rev,
    peer_rev_kind = peer.kind,
    peer_display = peer.display,
  })
end

return M
