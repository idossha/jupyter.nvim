
-- File: lua/nvim_jupyter/config.lua

local config = {}

config.settings = {
  python_cmd            = "python3",
  persistent_kernel_cmd = "ipython --simple-prompt --no-banner",
  output_height         = 10,
  auto_sync             = true,  -- automatically handle .ipynb custom save

  -- keymaps
  keymaps = {
    add_code_cell     = "<leader>jc",
    add_markdown_cell = "<leader>jm",
    run_cell          = "<leader>jr",
  },
}

function config.setup(user_config)
  config.settings = vim.tbl_extend("force", config.settings, user_config or {})

  -- Setup any keymaps
  local map_opts = { noremap = true, silent = true }
  vim.keymap.set("n", config.settings.keymaps.add_code_cell, function()
    require("nvim_jupyter.cell").add_cell("code")
  end, map_opts)

  vim.keymap.set("n", config.settings.keymaps.add_markdown_cell, function()
    require("nvim_jupyter.cell").add_cell("markdown")
  end, map_opts)

  vim.keymap.set("n", config.settings.keymaps.run_cell, function()
    require("nvim_jupyter.runner").run_current_cell()
  end, map_opts)
end

return config

