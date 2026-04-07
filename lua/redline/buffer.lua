local format = require("redline.format")
local util = require("redline.util")

local M = {}

function M.find(config)
  return util.find_buf(config.buf_name:gsub("%-", "%%-"))
end

function M.get_or_create(config)
  local existing = M.find(config)
  if existing then
    return existing
  end

  local bufnr = util.create_scratch_buffer({
    name = config.buf_name,
    filetype = "markdown",
    modifiable = true,
    bufhidden = "hide",
  })

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
