vim.api.nvim_create_user_command("Redline", function()
  local redline = require("redline")
  redline.show(redline.defaults)
end, { desc = "Open redline review buffer" })
