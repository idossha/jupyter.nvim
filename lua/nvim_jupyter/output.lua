-- File: lua/nvim_jupyter/output.lua

local output = {}
local config = require("nvim_jupyter.config").settings
local image = require("nvim_jupyter.image")

-- Store output windows for each buffer
output.windows = {}

-- Parse and format output for display
function output.format_output(raw_lines, cell_outputs)
  -- Process text output
  local formatted_lines = {}
  local has_content = false
  
  -- Add header
  table.insert(formatted_lines, "╭──────────────────────────────────────────╮")
  table.insert(formatted_lines, "│              CELL OUTPUT                 │")
  table.insert(formatted_lines, "╰──────────────────────────────────────────╯")
  
  -- Process raw text lines
  if raw_lines and #raw_lines > 0 then
    table.insert(formatted_lines, "")
    for _, line in ipairs(raw_lines) do
      if line ~= "" then
        has_content = true
        table.insert(formatted_lines, line)
      end
    end
  end
  
  -- Check for images in cell_outputs
  local image_count = 0
  if cell_outputs then
    image_count = image.process_output_images(cell_outputs)
    
    if image_count > 0 then
      has_content = true
      table.insert(formatted_lines, "")
      table.insert(formatted_lines, string.format("[ %d image%s displayed via terminal or external viewer ]", 
                                                 image_count, 
                                                 image_count > 1 and "s" or ""))
    end
  end
  
  if not has_content then
    table.insert(formatted_lines, "")
    table.insert(formatted_lines, "No output returned from cell execution")
  end
  
  table.insert(formatted_lines, "")
  table.insert(formatted_lines, "Press 'q' to close this window")
  
  return formatted_lines
end

-- Displays output in a floating window with nice formatting
function output.display_output(lines, cell_outputs)
  -- Create a scratch buffer
  local buf = vim.api.nvim_create_buf(false, true)  -- not listed, scratch buffer
  vim.bo[buf].buftype   = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile  = false
  vim.bo[buf].filetype  = "markdown"  -- For better syntax highlighting of output

  -- Format the output
  local formatted_lines = output.format_output(lines, cell_outputs)
  
  -- Insert the formatted output lines
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, formatted_lines)

  -- Set buffer-local keymaps
  local opts = { noremap = true, silent = true }
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<CR>", opts)
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<cmd>close<CR>", opts)

  -- Calculate dimensions for the floating window
  local max_width = math.min(120, vim.o.columns - 10)
  local width = max_width
  local height = math.min(math.max(#formatted_lines + 2, 10), math.floor(vim.o.lines * 0.8))
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local opts = {
    style    = "minimal",
    relative = "editor",
    width    = width,
    height   = height,
    row      = row,
    col      = col,
    border   = "rounded",
    title    = " Cell Output ",
    title_pos = "center",
  }

  -- Open the floating window
  local win_id = vim.api.nvim_open_win(buf, true, opts)
  
  -- Set window options
  vim.api.nvim_win_set_option(win_id, "winblend", 10)
  vim.api.nvim_win_set_option(win_id, "cursorline", false)
  
  -- Set highlight groups for better readability
  vim.cmd([[
    highlight JupyterOutputHeader guifg=#7dcfff gui=bold
    highlight JupyterOutputBorder guifg=#565f89
    highlight JupyterOutputHelp guifg=#9d7cd8
  ]])
  
  -- Apply highlights with matchadd()
  vim.api.nvim_win_call(win_id, function()
    vim.fn.matchadd('JupyterOutputHeader', "^│\\s*CELL OUTPUT\\s*│$")
    vim.fn.matchadd('JupyterOutputBorder', "^╭.*╮$")
    vim.fn.matchadd('JupyterOutputBorder', "^╰.*╯$")
    vim.fn.matchadd('JupyterOutputHelp', "^Press.*$")
  end)
  
  -- Store window info
  output.windows[buf] = {
    win_id = win_id,
    buffer = buf,
    created_at = os.time()
  }
  
  return win_id
end

-- Function to close all existing output windows
function output.close_all_windows()
  for buf, win_info in pairs(output.windows) do
    if vim.api.nvim_win_is_valid(win_info.win_id) then
      vim.api.nvim_win_close(win_info.win_id, true)
    end
    output.windows[buf] = nil
  end
end

-- Display output in dedicated sidebar split instead of floating window
function output.display_in_split(lines, cell_outputs)
  -- Close any existing output windows
  output.close_all_windows()
  
  -- Check if we already have a split
  local split_found = false
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local name = vim.api.nvim_buf_get_name(buf)
    if name:match("JupyterOutput$") then
      vim.api.nvim_set_current_win(win)
      split_found = true
      
      -- Clear the buffer
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
      
      -- Add formatted content
      local formatted_lines = output.format_output(lines, cell_outputs)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, formatted_lines)
      break
    end
  end
  
  if not split_found then
    -- Create new split
    vim.cmd("vsplit JupyterOutput")
    local buf = vim.api.nvim_get_current_buf()
    
    -- Configure buffer
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "markdown"
    
    -- Set buffer-local keymaps
    local opts = { noremap = true, silent = true }
    vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<CR>", opts)
    
    -- Add formatted content
    local formatted_lines = output.format_output(lines, cell_outputs)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, formatted_lines)
    
    -- Set width
    vim.cmd("vertical resize 60")
    
    -- Set highlight groups for better readability
    vim.cmd([[
      highlight JupyterOutputHeader guifg=#7dcfff gui=bold
      highlight JupyterOutputBorder guifg=#565f89
      highlight JupyterOutputHelp guifg=#9d7cd8
    ]])
    
    -- Apply highlights with matchadd()
    vim.fn.matchadd('JupyterOutputHeader', "^│\\s*CELL OUTPUT\\s*│$")
    vim.fn.matchadd('JupyterOutputBorder', "^╭.*╮$")
    vim.fn.matchadd('JupyterOutputBorder', "^╰.*╯$")
    vim.fn.matchadd('JupyterOutputHelp', "^Press.*$")
  end
  
  -- Return to the main window
  vim.cmd("wincmd p")
end

return output