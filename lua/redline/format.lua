local M = {}

local DEFAULT_PROMPT = {
  "# AI Review Packet",
  "",
  "You are reviewing code changes.",
  "Treat each review item as a separate code review concern.",
  "Prioritize correctness bugs, regressions, missing edge cases, risky behavior changes, and unclear intent.",
  "Be concrete and skeptical. Do not assume the code is correct.",
  "For each item, explain the risk, why it matters, and what change you recommend.",
  "Respond item-by-item and reference the review item number in your answer.",
  "",
}

local function prompt_lines(config)
  if config.prompt_lines == false then
    return {}
  end
  if type(config.prompt_lines) == "table" then
    return vim.deepcopy(config.prompt_lines)
  end
  return vim.deepcopy(DEFAULT_PROMPT)
end

function M.preamble(config)
  local lines = prompt_lines(config)
  local repo_type = config.repo_type or "unknown"
  local repo_root = config.repo_root
  if type(repo_root) == "function" then
    repo_root = repo_root()
  end
  repo_root = repo_root or "unknown"
  local source = config.source or (repo_type .. " unified diff review")

  vim.list_extend(lines, {
    "## Repository Context",
    "- Repo type: " .. repo_type,
    "- Repository root: " .. repo_root,
    "- Source: " .. source,
    "",
    "## Review Items",
    "",
  })
  return lines
end

function M.format_entry(entry, number)
  local lines = { "### Review Item " .. number }

  -- Unified diff fields (jj-fugitive / sl-fugitive style)
  if entry.rev and entry.rev ~= "" then
    table.insert(lines, "- Revision: " .. entry.rev)
  end

  if entry.source and entry.source ~= "" then
    table.insert(lines, "- Source: " .. entry.source)
  end

  if entry.node and entry.node ~= "" and entry.node ~= entry.rev then
    table.insert(lines, "- Changeset: " .. entry.node)
  end

  if entry.summary and entry.summary ~= "" then
    table.insert(lines, "- Summary: " .. entry.summary)
  end

  if entry.author and entry.author ~= "" then
    table.insert(lines, "- Author: " .. entry.author)
  end

  if entry.date and entry.date ~= "" then
    table.insert(lines, "- Date: " .. entry.date)
  end

  -- File path (unified diff uses "file", difftool uses "path")
  local filepath = entry.file or entry.path
  if filepath and filepath ~= "" then
    table.insert(lines, "- File: " .. filepath)
  end

  -- DiffTool fields
  if entry.side then
    table.insert(lines, "- Side: " .. entry.side)
  end

  if entry.peer_path and entry.peer_path ~= "" then
    table.insert(lines, "- Peer path: " .. entry.peer_path)
  end

  if entry.peer_rev and entry.peer_rev ~= "" then
    table.insert(lines, "- Peer revision: " .. entry.peer_rev)
  end

  if entry.line_number then
    table.insert(lines, "- Line: " .. tostring(entry.line_number))
  end

  if entry.qf_text and entry.qf_text ~= "" then
    table.insert(lines, "- Quickfix entry: " .. entry.qf_text)
  end

  if entry.qf_lnum and entry.qf_lnum > 0 then
    table.insert(lines, "- Quickfix line: " .. tostring(entry.qf_lnum))
  end

  if entry.hunk and entry.hunk ~= "" then
    table.insert(lines, "- Hunk: " .. entry.hunk)
  end

  -- Selected line / change line
  local selected = entry.selected_line or entry.change
  table.insert(lines, "- Selected line:")
  table.insert(lines, "```diff")
  table.insert(lines, (selected and selected ~= "") and selected or "(blank line)")
  table.insert(lines, "```")

  -- DiffTool hunk snippet
  if entry.hunk_lines and #entry.hunk_lines > 0 then
    table.insert(lines, "- Hunk snippet:")
    table.insert(lines, "```diff")
    vim.list_extend(lines, entry.hunk_lines)
    table.insert(lines, "```")
  end

  -- DiffTool context
  if entry.context and #entry.context > 0 then
    table.insert(lines, "- Context:")
    vim.list_extend(lines, entry.context)
  end

  -- Reviewer comment
  table.insert(lines, "- Reviewer comment:")
  if entry.comment then
    for _, line in ipairs(vim.split(entry.comment, "\n", { plain = true })) do
      table.insert(lines, "  " .. line)
    end
  end

  table.insert(lines, "")
  return lines
end

function M.next_comment_number(bufnr)
  local count = 0
  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    if line:match("^### Review Item %d+$") then
      count = count + 1
    end
  end
  return count + 1
end

return M
