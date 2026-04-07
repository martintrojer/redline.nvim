local M = {}

local function current_qf_entry()
  local info = vim.fn.getqflist({ idx = 0, items = 0 })
  local idx = info.idx or 0
  local items = info.items or {}
  if idx < 1 or idx > #items then
    return nil
  end
  return items[idx]
end

local function diff_windows()
  local wins = {}
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(winid) and vim.wo[winid].diff then
      table.insert(wins, winid)
    end
  end
  table.sort(wins, function(a, b)
    local posa = vim.api.nvim_win_get_position(a)
    local posb = vim.api.nvim_win_get_position(b)
    if posa[1] == posb[1] then
      return posa[2] < posb[2]
    end
    return posa[1] < posb[1]
  end)
  return wins
end

function M.current()
  local winid = vim.api.nvim_get_current_win()
  if not vim.wo[winid].diff then
    return nil, "Current window is not a diff window"
  end

  local wins = diff_windows()
  if #wins < 2 then
    return nil, "Need at least two diff windows"
  end

  local current_idx
  for idx, id in ipairs(wins) do
    if id == winid then
      current_idx = idx
      break
    end
  end
  if not current_idx then
    return nil, "Could not locate current diff window"
  end

  local peer_idx = current_idx == 1 and 2 or current_idx - 1
  local peer_win = wins[peer_idx]
  local side = current_idx == 1 and "left" or "right"

  return {
    winid = winid,
    bufnr = vim.api.nvim_win_get_buf(winid),
    peer_win = peer_win,
    peer_bufnr = vim.api.nvim_win_get_buf(peer_win),
    side = side,
    qf_entry = current_qf_entry(),
  }
end

return M
