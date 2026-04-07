vim.api.nvim_create_user_command("Redline", function()
  require("redline").show()
end, { desc = "Open redline review buffer" })
