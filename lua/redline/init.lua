local M = {}

M.defaults = {
  repo_type = nil,
  repo_root = nil,
  open_mode = "split",
  buf_name = "redline-review",
  prompt_lines = nil,
  source = nil,
  on_show = nil,
  providers = {},
}

function M.make_config(opts)
  return vim.tbl_extend("force", M.defaults, opts or {})
end

function M.setup(opts)
  M.defaults = vim.tbl_extend("force", M.defaults, opts or {})

  if M.defaults.providers.minigit then
    require("redline.providers.minigit").setup(M.defaults)
  end
  if M.defaults.providers.difftool then
    require("redline.providers.difftool").setup(M.defaults)
  end
end

function M.show(config)
  return require("redline.buffer").show(config)
end

function M.append(config, entry)
  if entry.vcs then
    config.repo_type = entry.vcs
  end
  if entry.repo_root then
    config.repo_root = entry.repo_root
  end
  local number, bufnr = require("redline.buffer").append(config, entry)
  require("redline.util").info("Review added (" .. number .. ")")
  return number, bufnr
end

function M.comment(config, bufnr, entry_fn)
  local entry, err = entry_fn(bufnr)
  if not entry then
    require("redline.util").warn(err)
    return
  end

  vim.ui.input({ prompt = "Review comment: " }, function(comment)
    if not comment or comment:match("^%s*$") then
      return
    end
    entry.comment = comment
    M.append(config, entry)
  end)
end

function M.extract_unified_diff_entry(bufnr, ctx)
  local parse = require("redline.parse")
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local change_line = lines[cursor_line] or ""
  local file = ctx.file or parse.find_file_for_cursor(lines, cursor_line)
  if not file then
    return nil, "Place the cursor on a diff line"
  end

  return {
    file = file,
    rev = ctx.rev or "@",
    node = ctx.node,
    source = ctx.source,
    summary = ctx.summary,
    author = ctx.author,
    date = ctx.date,
    hunk = parse.find_hunk_for_cursor(lines, cursor_line, 1, function(line)
      return line
    end),
    change = change_line,
  }
end

function M.extract_inline_diff_entry(bufnr, ranges)
  local parse = require("redline.parse")
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local active
  for _, item in ipairs(ranges) do
    if cursor_line >= item.start_line and cursor_line <= item.end_line then
      active = item
      break
    end
  end

  if not active then
    return nil, "Place the cursor on an inline diff line"
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local change_line = parse.trim_inline_prefix(lines[cursor_line] or "")
  return {
    file = active.file,
    rev = active.rev or "@",
    node = active.node,
    source = active.source or "status inline diff",
    summary = active.summary,
    author = active.author,
    date = active.date,
    hunk = parse.find_hunk_for_cursor(
      lines,
      cursor_line,
      active.start_line,
      parse.trim_inline_prefix
    ),
    change = change_line,
  }
end

function M.comment_unified_diff(config, bufnr, ctx)
  M.comment(config, bufnr, function(b)
    return M.extract_unified_diff_entry(b, ctx)
  end)
end

return M
