local M = {}

function M.map(bufnr, mode, lhs, rhs, opts)
  local base = { buffer = bufnr, noremap = true, silent = true }
  if opts then
    base = vim.tbl_extend("force", base, opts)
  end
  vim.keymap.set(mode, lhs, rhs, base)
end

function M.buf_var(bufnr, name, default)
  local ok, val = pcall(vim.api.nvim_buf_get_var, bufnr, name)
  return ok and val or default
end

function M.info(msg)
  vim.notify(msg, vim.log.levels.INFO)
end

function M.warn(msg)
  vim.notify(msg, vim.log.levels.WARN)
end

function M.find_buf(pattern)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name:match(pattern) then
        return bufnr
      end
    end
  end
  return nil
end

function M.ensure_visible(bufnr, open_mode)
  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
        vim.api.nvim_set_current_tabpage(tabpage)
        vim.api.nvim_set_current_win(win)
        return
      end
    end
  end
  M.open_pane(open_mode)
  vim.api.nvim_set_current_buf(bufnr)
end

function M.open_pane(open_mode)
  local cmd = open_mode == "tab" and "tabnew" or "split"
  vim.cmd(cmd)

  if cmd == "tabnew" then
    local stray = vim.api.nvim_get_current_buf()
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(stray) and vim.api.nvim_buf_get_name(stray) == "" then
        pcall(vim.api.nvim_buf_delete, stray, { force = true })
      end
    end)
  end
end

function M.set_statusline(bufnr, text)
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd("setlocal statusline=" .. vim.fn.escape(text or "", " \\ "))
  end)
end

function M.close_cmd(open_mode)
  return open_mode == "tab" and "tabclose" or "close"
end

function M.run(cmd, cwd)
  local result = vim.system(cmd, { cwd = cwd, text = true }):wait()
  if result.code ~= 0 then
    return nil
  end
  local s = result.stdout
  if s then
    s = s:gsub("%s+$", "")
    if s == "" then
      return nil
    end
  end
  return s
end

function M.run_first(cmds, cwd)
  for _, cmd in ipairs(cmds) do
    local out = M.run(cmd, cwd)
    if out then
      return out
    end
  end
  return nil
end

function M.shorten_hash(value, len)
  if not value or value == "" then
    return nil
  end
  len = len or 12
  if #value <= len then
    return value
  end
  return value:sub(1, len)
end

function M.file_hash(path)
  if not path or path == "" or vim.fn.filereadable(path) ~= 1 then
    return nil
  end
  local cwd = vim.fn.fnamemodify(path, ":p:h")
  local abs = vim.fn.fnamemodify(path, ":p")

  local sha = M.run_first({
    { "sha256sum", abs },
    { "shasum", "-a", "256", abs },
    { "openssl", "dgst", "-sha256", abs },
  }, cwd)
  if not sha then
    return nil
  end

  return sha:match("^([0-9a-fA-F]+)") or sha
end

return M
