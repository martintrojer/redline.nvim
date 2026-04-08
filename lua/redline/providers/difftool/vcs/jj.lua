local base = require("redline.providers.difftool.vcs.base")
local util = require("redline.util")

local M = {
  name = "jj",
}

function M.diff_for_path(ctx)
  local relpath = base.repo_relpath(ctx)
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
    return { rev = revset, display = revset }
  end
  local change_id, commit_id = out:match("^(%S+)%s+(%S+)$")
  if not change_id then
    return { rev = revset, display = revset }
  end

  return {
    rev = commit_id,
    display = string.format("%s %s %s", revset, change_id, commit_id),
  }
end

function M.resolve_session(ctx)
  local at = rev_spec(ctx.detection.repo_root, "@")
  local parent = rev_spec(ctx.detection.repo_root, "@-")
  return base.resolve_sides(ctx, at, parent)
end

return M
