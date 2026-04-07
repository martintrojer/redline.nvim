local M = {}

local MARKERS = {
  { marker = ".jj", vcs = "jj", provider = "jj" },
  { marker = ".hg", vcs = "hg", provider = "hg" },
  { marker = ".git", vcs = "git", provider = "git" },
}

function M.normalize_dir(path)
  if not path or path == "" then
    return nil
  end
  local expanded = vim.fn.fnamemodify(path, ":p")
  if vim.fn.isdirectory(expanded) == 1 then
    return expanded:gsub("/$", "")
  end
  return vim.fn.fnamemodify(expanded, ":h"):gsub("/$", "")
end

function M.find_root(start_dir)
  if not start_dir then
    return nil
  end

  for _, item in ipairs(MARKERS) do
    local found = vim.fs.find(item.marker, {
      path = start_dir,
      upward = true,
      type = "directory",
    })
    if #found > 0 then
      local repo_root = vim.fn.fnamemodify(found[1], ":h")
      return {
        vcs = item.vcs,
        provider = item.provider,
        repo_root = repo_root,
        packet_key = repo_root,
      }
    end
  end

  return nil
end

function M.detect(...)
  local candidates = { ... }
  table.insert(candidates, vim.fn.getcwd())

  for _, candidate in ipairs(candidates) do
    local start_dir = M.normalize_dir(candidate)
    local found = M.find_root(start_dir)
    if found then
      return found
    end
  end

  local fallback = M.normalize_dir(candidates[1]) or vim.fn.getcwd()
  return {
    vcs = "unknown",
    provider = "unknown",
    repo_root = fallback,
    packet_key = fallback,
  }
end

function M.relative_path(path, root)
  if not path or path == "" then
    return nil
  end
  if not root or root == "" then
    return vim.fn.fnamemodify(path, ":.")
  end

  local abs = vim.fn.fnamemodify(path, ":p"):gsub("/$", "")
  local prefix = vim.fn.fnamemodify(root, ":p"):gsub("/$", "")
  if abs:sub(1, #prefix + 1) == prefix .. "/" then
    return abs:sub(#prefix + 2)
  end
  if abs == prefix then
    return "."
  end
  return abs
end

function M.is_inside_root(path, root)
  if not path or path == "" or not root or root == "" then
    return false
  end

  local abs = vim.fn.fnamemodify(path, ":p"):gsub("/$", "")
  local prefix = vim.fn.fnamemodify(root, ":p"):gsub("/$", "")
  return abs == prefix or abs:sub(1, #prefix + 1) == prefix .. "/"
end

return M
