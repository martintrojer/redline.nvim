local base = require("redline.providers.difftool.vcs.base")
local util = require("redline.util")

local M = {
  name = "hg",
}

function M.diff_for_path(ctx)
  local relpath = base.repo_relpath(ctx)
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

function M.resolve_session(ctx)
  local dot = rev_spec(ctx.detection.repo_root, ".")
  local file_hash =
    util.shorten_hash(manifest_file_hash(ctx.detection.repo_root, base.repo_relpath(ctx)))
  if file_hash then
    dot.display = dot.display .. " file " .. file_hash
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

  return base.resolve_sides(ctx, worktree_spec(ctx.current_path), dot)
end

return M
