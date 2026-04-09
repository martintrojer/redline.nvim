local M = {}

local initialized = false

local function parse_revision(args)
  if not args or #args == 0 then
    return nil
  end

  local subcmd = args[1]
  if subcmd ~= "diff" and subcmd ~= "show" then
    return nil
  end

  -- Collect non-flag arguments after the subcommand, stopping at "--"
  local positional = {}
  local i = 2
  while i <= #args do
    local arg = args[i]
    if arg == "--" then
      break
    end
    if arg:sub(1, 1) ~= "-" then
      table.insert(positional, arg)
    end
    i = i + 1
  end

  if subcmd == "show" then
    return positional[1] or "HEAD"
  end

  -- git diff
  if #positional == 0 then
    return "worktree vs index"
  end

  -- Check for --cached/--staged flag
  for _, a in ipairs(args) do
    if a == "--cached" or a == "--staged" then
      return "index vs HEAD"
    end
  end

  return positional[1]
end

function M.setup(_defaults)
  if initialized then
    return
  end
  initialized = true

  M.config = require("redline").make_config({
    repo_type = "git",
    buf_name = "redline-git",
    source = "fugitive review",
    repo_root = function()
      return M.last_cwd or vim.fn.getcwd()
    end,
  })

  local group = vim.api.nvim_create_augroup("RedlineFugitive", { clear = true })

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "FugitivePager",
    callback = function(au_data)
      vim.schedule(function()
        M.on_pager(au_data.buf)
      end)
    end,
  })
end

function M.on_pager(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  if require("redline.util").buf_var(bufnr, "redline_fugitive_keymaps_set", false) then
    return
  end

  local ok, result = pcall(vim.fn.FugitiveResult, bufnr)
  if not ok or type(result) ~= "table" then
    return
  end

  local args = result.args or {}
  local subcmd = args[1]
  M.last_cwd = result.cwd

  pcall(vim.api.nvim_buf_set_var, bufnr, "redline_fugitive_keymaps_set", true)

  local redline = require("redline")
  local util = require("redline.util")

  if subcmd == "diff" or subcmd == "show" then
    local rev = parse_revision(args) or "HEAD"
    local ctx = {
      file = nil,
      rev = rev,
      source = "fugitive " .. subcmd,
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
