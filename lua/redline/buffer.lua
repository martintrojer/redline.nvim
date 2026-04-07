local format = require("redline.format")
local util = require("redline.util")

local M = {}

function M.find(config)
  return util.find_buf(config.buf_name:gsub("%-", "%%-"))
end

local function preamble_end(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for i, line in ipairs(lines) do
    if line == "## Review Items" then
      return i + 1 -- line after "## Review Items" (+ blank line)
    end
  end
  return nil
end

local function update_preamble(bufnr, config)
  local end_line = preamble_end(bufnr)
  if not end_line then
    return
  end
  local new_preamble = format.preamble(config)
  vim.api.nvim_buf_set_lines(bufnr, 0, end_line, false, new_preamble)
  vim.bo[bufnr].modified = false
end

function M.get_or_create(config)
  local existing = M.find(config)
  if existing then
    update_preamble(existing, config)
    return existing
  end

  local bufnr = vim.api.nvim_create_buf(true, false)
  pcall(vim.api.nvim_buf_set_name, bufnr, config.buf_name)
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "hide"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].filetype = "markdown"
  vim.bo[bufnr].modifiable = true

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, format.preamble(config))
  vim.bo[bufnr].modified = false

  util.map(bufnr, "n", "q", function()
    vim.cmd(util.close_cmd(config.open_mode))
  end)

  return bufnr
end

function M.show(config)
  local bufnr = M.get_or_create(config)
  util.ensure_visible(bufnr, config.open_mode)
  util.set_statusline(bufnr, config.buf_name)
  if config.on_show then
    config.on_show(bufnr)
  end
  return bufnr
end

function M.append(config, entry)
  local bufnr = M.get_or_create(config)
  local number = format.next_comment_number(bufnr)
  local lines = format.format_entry(entry, number)
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  vim.api.nvim_buf_set_lines(bufnr, line_count, line_count, false, lines)
  vim.bo[bufnr].modified = false

  return number, bufnr
end

return M
