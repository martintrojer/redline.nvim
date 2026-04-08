local M = {}

local initialized = false

local function difftool_active()
  local ok, autocmds = pcall(vim.api.nvim_get_autocmds, { group = "nvim.difftool.events" })
  return ok and #autocmds > 0
end

local function set_buffer_keymaps(bufnr)
  if vim.b[bufnr].redline_difftool_keymaps_set then
    return
  end
  vim.b[bufnr].redline_difftool_keymaps_set = true

  local opts = { buffer = bufnr, silent = true }
  vim.keymap.set("n", "cR", function()
    M.comment_current()
  end, opts)
  vim.keymap.set("n", "gR", function()
    M.open_review()
  end, opts)
end

local function maybe_attach(bufnr)
  if vim.bo[bufnr].buftype ~= "" then
    return
  end
  if not difftool_active() then
    return
  end

  local wins = vim.fn.win_findbuf(bufnr)
  for _, winid in ipairs(wins) do
    if vim.api.nvim_win_is_valid(winid) and vim.wo[winid].diff then
      set_buffer_keymaps(bufnr)
      return
    end
  end
end

local function schedule_attach(bufnr)
  vim.defer_fn(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      maybe_attach(bufnr)
    end
  end, 50)
end

function M.setup(_defaults)
  if initialized then
    return
  end
  initialized = true

  M.config = require("redline").make_config({
    buf_name = "redline-difftool",
    source = "DiffTool",
  })

  local group = vim.api.nvim_create_augroup("RedlineDifftool", { clear = true })
  vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
    group = group,
    callback = function(args)
      schedule_attach(args.buf)
    end,
  })
end

function M.open_review()
  require("redline").show(M.config)
end

function M.comment_current()
  require("redline").comment(M.config, vim.api.nvim_get_current_buf(), function(_)
    return require("redline.providers.difftool.extract").current()
  end)
end

return M
