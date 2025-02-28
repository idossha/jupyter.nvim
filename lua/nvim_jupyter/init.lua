
-- File: lua/nvim_jupyter/init.lua
--
-- Jupyter.nvim - A professional Jupyter notebook interface for Neovim
--
-- Author: Ido Haber
-- License: MIT
-- Version: 1.0.0

local M = {}

-- Load all submodules and expose them
M.config       = require("nvim_jupyter.config")
M.cell         = require("nvim_jupyter.cell")
M.cell_ui      = require("nvim_jupyter.cell_ui")
M.runner       = require("nvim_jupyter.runner")
M.output       = require("nvim_jupyter.output")
M.image        = require("nvim_jupyter.image")
M.workspace    = require("nvim_jupyter.workspace")
M.fix_notebook = require("nvim_jupyter.fix_notebook")

-- Initialization function called from plugin entry point
function M.setup(user_config)
  -- Process user configuration
  M.config.setup(user_config or {})
  
  -- Register any additional commands
  M.config.register_commands()
  
  -- Initialize all modules
  M.cell.setup()
  M.cell_ui.setup()
  M.runner.setup()
  M.workspace.setup()
  
  -- Create command for fixing notebooks
  vim.api.nvim_create_user_command('JupyterFixNotebook', function()
    M.fix_notebook.fix_current_notebook()
  end, {})
  
  -- Display a welcome message
  if user_config and user_config.show_welcome ~= false then
    vim.defer_fn(function()
      vim.notify("Jupyter.nvim initialized! Use JupyterKeymapHelp to see available commands.", 
        vim.log.levels.INFO)
    end, 1000)
  end
  
  -- Return the fully initialized module
  return M
end

-- Expose key functionality as top-level methods for ease of use
function M.run_cell()
  M.runner.run_current_cell()
end

function M.add_cell(cell_type)
  M.cell.add_cell(cell_type or "code")
end

function M.restart_kernel()
  M.runner.restart_kernel()
end

function M.show_workspace()
  M.workspace.show_ui()
end

function M.show_keymap_help()
  M.config.show_keymap_help()
end

return M
