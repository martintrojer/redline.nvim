local base = require("redline.providers.difftool.vcs.base")
local util = require("redline.util")

local M = {
  name = "git",
}

function M.diff_for_path(ctx)
  local relpath = base.repo_relpath(ctx)
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
  local head = util.run({ "git", "rev-parse", "HEAD" }, ctx.detection.repo_root)

  local function committed_spec()
    local relpath = base.repo_relpath(ctx)
    local short = util.shorten_hash(head)
    local blob = head_blob(ctx.detection.repo_root, relpath)
    local blob_short = util.shorten_hash(blob)
    local display = short and ("HEAD " .. short) or "HEAD"
    if blob_short then
      display = display .. " blob " .. blob_short
    end
    return {
      rev = head or "HEAD",
      display = display,
    }
  end

  return base.resolve_sides(ctx, base.worktree_spec(ctx.current_path), committed_spec())
end

return M
