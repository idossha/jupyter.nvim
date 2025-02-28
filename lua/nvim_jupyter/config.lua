
-- File: lua/nvim_jupyter/config.lua

local config = {}

-- Default configuration
config.settings = {
  -- Jupyter kernel settings
  python_cmd            = "python3",
  persistent_kernel_cmd = "ipython --simple-prompt --no-banner",
  
  -- UI settings
  output_height         = 15,
  output_style          = "float",   -- "float" or "split"
  move_to_next_cell     = true,      -- Move to next cell after execution
  auto_sync             = true,      -- Automatically handle .ipynb custom save
  enable_cell_borders   = true,      -- Show cell borders with colors and styling
  enable_images         = true,      -- Enable inline image display
  
  -- Theme colors (can be overridden)
  theme = {
    cell_bg_code       = "#1a2b3c",
    cell_bg_markdown   = "#2a2837",
    cell_border_code   = "#3d5a7a",
    cell_border_markdown = "#4d456d",
    active_cell_bg     = "#253040",
    active_cell_border = "#5194d0",
  },

  -- Keymaps with descriptions
  keymaps = {
    add_code_cell     = { key = "<leader>jc", desc = "Add a new code cell below cursor" },
    add_markdown_cell = { key = "<leader>jm", desc = "Add a new markdown cell below cursor" },
    run_cell          = { key = "<leader>jr", desc = "Run the current cell" },
    run_all_cells     = { key = "<leader>ja", desc = "Run all cells in the notebook" },
    run_to_cell       = { key = "<leader>jt", desc = "Run all cells until current cell" },
    move_next_cell    = { key = "<leader>jn", desc = "Move cursor to the next cell" },
    move_prev_cell    = { key = "<leader>jp", desc = "Move cursor to the previous cell" },
    restart_kernel    = { key = "<leader>jk", desc = "Restart Jupyter kernel" },
    open_workspace    = { key = "<leader>jw", desc = "Open the Jupyter workspace panel" },
    toggle_output     = { key = "<leader>jo", desc = "Toggle between float/split output display" },
    toggle_visual     = { key = "<leader>jv", desc = "Toggle visual cell borders" },
    open_in_browser   = { key = "<leader>jb", desc = "Open notebook in Jupyter browser" },
  },
}

-- Creates a keymap with proper description
local function create_keymap(mode, lhs, rhs, desc, opts)
  opts = opts or {}
  opts.desc = desc
  vim.keymap.set(mode, lhs, rhs, opts)
end

-- Setup configuration with user overrides
function config.setup(user_config)
  -- Merge user settings with defaults
  if user_config then
    -- Special handling for nested tables
    if user_config.theme then
      config.settings.theme = vim.tbl_deep_extend("force", config.settings.theme, user_config.theme)
      user_config.theme = nil
    end
    
    if user_config.keymaps then
      for k, v in pairs(user_config.keymaps) do
        if type(v) == "string" then
          -- Convert string format to table format with description
          config.settings.keymaps[k] = { key = v, desc = config.settings.keymaps[k].desc }
        else
          -- Use provided description or keep default
          config.settings.keymaps[k] = {
            key = v.key or config.settings.keymaps[k].key,
            desc = v.desc or config.settings.keymaps[k].desc
          }
        end
      end
      user_config.keymaps = nil
    end
    
    -- Merge remaining top-level settings
    config.settings = vim.tbl_deep_extend("force", config.settings, user_config)
  end

  -- Setup keymaps with descriptions
  local map_opts = { noremap = true, silent = true }
  
  -- Basic cell operations
  create_keymap("n", config.settings.keymaps.add_code_cell.key, function()
    require("nvim_jupyter.cell").add_cell("code")
  end, config.settings.keymaps.add_code_cell.desc, map_opts)

  create_keymap("n", config.settings.keymaps.add_markdown_cell.key, function()
    require("nvim_jupyter.cell").add_cell("markdown")
  end, config.settings.keymaps.add_markdown_cell.desc, map_opts)

  create_keymap("n", config.settings.keymaps.run_cell.key, function()
    require("nvim_jupyter.runner").run_current_cell()
  end, config.settings.keymaps.run_cell.desc, map_opts)
  
  -- Advanced cell operations
  create_keymap("n", config.settings.keymaps.run_all_cells.key, function()
    require("nvim_jupyter.runner").run_all_cells()
  end, config.settings.keymaps.run_all_cells.desc, map_opts)
  
  create_keymap("n", config.settings.keymaps.run_to_cell.key, function()
    require("nvim_jupyter.runner").run_cells_to_cursor()
  end, config.settings.keymaps.run_to_cell.desc, map_opts)
  
  -- Navigation
  create_keymap("n", config.settings.keymaps.move_next_cell.key, function()
    require("nvim_jupyter.cell").move_to_next_cell()
  end, config.settings.keymaps.move_next_cell.desc, map_opts)
  
  create_keymap("n", config.settings.keymaps.move_prev_cell.key, function()
    require("nvim_jupyter.cell").move_to_prev_cell()
  end, config.settings.keymaps.move_prev_cell.desc, map_opts)
  
  -- Kernel management
  create_keymap("n", config.settings.keymaps.restart_kernel.key, function()
    require("nvim_jupyter.runner").restart_kernel()
  end, config.settings.keymaps.restart_kernel.desc, map_opts)
  
  -- Workspace
  create_keymap("n", config.settings.keymaps.open_workspace.key, function()
    require("nvim_jupyter.workspace").show_ui()
  end, config.settings.keymaps.open_workspace.desc, map_opts)
  
  -- Output display toggle
  create_keymap("n", config.settings.keymaps.toggle_output.key, function()
    config.settings.output_style = config.settings.output_style == "float" and "split" or "float"
    local mode = config.settings.output_style == "float" and "floating window" or "split"
    vim.notify("Jupyter output display changed to: " .. mode, vim.log.levels.INFO)
  end, config.settings.keymaps.toggle_output.desc, map_opts)
  
  -- Toggle visual cell borders
  create_keymap("n", config.settings.keymaps.toggle_visual.key, function()
    require("nvim_jupyter.cell_ui").toggle_visual_rendering()
  end, config.settings.keymaps.toggle_visual.desc, map_opts)
  
  -- Open notebook in browser
  create_keymap("n", config.settings.keymaps.open_in_browser.key, function()
    require("nvim_jupyter.runner").open_in_jupyter_server()
  end, config.settings.keymaps.open_in_browser.desc, map_opts)
end

-- Print keymap help to a floating window
function config.show_keymap_help()
  local lines = {
    "╭────────────────────────────────────────────────╮",
    "│           Jupyter.nvim Keymap Help             │",
    "╰────────────────────────────────────────────────╯",
    ""
  }
  
  for name, km in pairs(config.settings.keymaps) do
    table.insert(lines, string.format("  %-16s : %-7s : %s", 
                                     name:gsub("_", " "):upper(), 
                                     km.key,
                                     km.desc))
  end
  
  table.insert(lines, "")
  table.insert(lines, "Press 'q' to close this window")
  
  -- Create a scratch buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  
  -- Add the keymap help content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  -- Set buffer-local keymap to close
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<CR>", {noremap = true, silent = true})
  
  -- Calculate window dimensions
  local width = 60
  local height = #lines
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  -- Open the floating window
  local win_opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Jupyter Keymap Help ",
    title_pos = "center"
  }
  
  local win_id = vim.api.nvim_open_win(buf, true, win_opts)
  
  -- Set window options
  vim.api.nvim_win_set_option(win_id, "winblend", 10)
  
  -- Set highlight groups
  vim.cmd("highlight JupyterKeymapHeader guifg=#7dcfff gui=bold")
  vim.cmd("highlight JupyterKeymapBorder guifg=#565f89")
  vim.cmd("highlight JupyterKeymapKey guifg=#9ece6a gui=bold")
  
  -- Apply highlights
  vim.api.nvim_win_call(win_id, function()
    vim.fn.matchadd('JupyterKeymapHeader', "^│.*Jupyter.nvim.*│$")
    vim.fn.matchadd('JupyterKeymapBorder', "^╭.*╮$")
    vim.fn.matchadd('JupyterKeymapBorder', "^╰.*╯$")
    vim.fn.matchadd('JupyterKeymapKey', ":\\s\\+<.*>\\s\\+:")
  end)
end

-- Create user command for showing keymap help
function config.register_commands()
  vim.api.nvim_create_user_command('JupyterKeymapHelp', function()
    config.show_keymap_help()
  end, {})
end

return config

