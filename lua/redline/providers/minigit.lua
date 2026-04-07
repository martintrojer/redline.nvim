local M = {}

local initialized = false

local function parse_revision(git_command)
  if not git_command or #git_command < 2 then
    return nil
  end

  local subcmd = git_command[2]
  if subcmd ~= "diff" and subcmd ~= "show" then
    return nil
  end

  -- Collect non-flag arguments after the subcommand, stopping at "--"
  local args = {}
  local i = 3
  while i <= #git_command do
    local arg = git_command[i]
    if arg == "--" then
      break
    end
    if arg:sub(1, 1) ~= "-" then
      table.insert(args, arg)
    end
    i = i + 1
  end

  if subcmd == "show" then
    return args[1] or "HEAD"
  end

  -- git diff
  if #args == 0 then
    return "worktree vs index"
  end

  -- Check for --cached/--staged flag
  for _, a in ipairs(git_command) do
    if a == "--cached" or a == "--staged" then
      return "index vs HEAD"
    end
  end

  return args[1]
end

function M.setup(_defaults)
  if initialized then
    return
  end
  initialized = true

  M.config = require("redline").make_config({
    repo_type = "git",
    buf_name = "redline-git",
    source = "mini.git review",
    repo_root = function()
      return M.last_cwd or vim.fn.getcwd()
    end,
  })

  vim.api.nvim_create_autocmd("User", {
    pattern = "MiniGitCommandSplit",
    callback = function(au_data)
      M.on_split(au_data)
    end,
  })
end

function M.on_split(au_data)
  local data = au_data.data or {}
  local subcmd = data.git_subcommand
  M.last_cwd = data.cwd
  local bufnr = data.win_stdout and vim.fn.winbufnr(data.win_stdout) or nil
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local redline = require("redline")
  local util = require("redline.util")

  if subcmd == "diff" or subcmd == "show" then
    local rev = parse_revision(data.git_command) or "HEAD"
    local ctx = {
      file = nil,
      rev = rev,
      source = "mini.git " .. subcmd,
    }

    util.map(bufnr, "n", "cR", function()
      redline.comment_unified_diff(M.config, bufnr, ctx)
    end)
    util.map(bufnr, "n", "gR", function()
      redline.show(M.config)
    end)
  elseif subcmd == "log" or subcmd == "blame" then
    util.map(bufnr, "n", "gR", function()
      redline.show(M.config)
    end)
  end
end

return M
