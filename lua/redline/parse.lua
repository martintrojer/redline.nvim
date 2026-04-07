local M = {}

function M.find_file_for_cursor(lines, cursor_line)
  for i = cursor_line, 1, -1 do
    local old_file, new_file = lines[i]:match("^diff %-%-git a/(.-) b/(.-)$")
    if new_file and new_file ~= "" then
      return new_file
    end
    if old_file and old_file ~= "" then
      return old_file
    end
  end
  return nil
end

function M.find_hunk_for_cursor(lines, cursor_line, start_line, normalize)
  for i = cursor_line, start_line, -1 do
    local line = normalize(lines[i])
    if line:match("^@@") then
      return line
    end
  end
  return nil
end

function M.trim_inline_prefix(line)
  return (line or ""):gsub("^    ", "")
end

return M
