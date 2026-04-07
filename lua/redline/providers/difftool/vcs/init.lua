local M = {}

local function provider_name(detection)
  return (detection and detection.provider) or "unknown"
end

function M.for_detection(detection)
  local name = provider_name(detection)
  local module_name = "redline.providers.difftool.vcs." .. name
  local ok, provider = pcall(require, module_name)
  if ok and provider then
    return provider
  end
  local missing = type(provider) == "string"
    and provider:match("module '" .. module_name:gsub("%-", "%%-") .. "' not found")
  if not missing then
    vim.notify(
      "redline: failed to load provider " .. name .. ": " .. tostring(provider),
      vim.log.levels.ERROR
    )
  end
  return require("redline.providers.difftool.vcs.unknown")
end

return M
