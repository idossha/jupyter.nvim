
-- File: lua/nvim_jupyter/runner.lua
local M = {}

local cell     = require("nvim_jupyter.cell")
local output   = require("nvim_jupyter.output")
local config   = require("nvim_jupyter.config").settings
local image    = require("nvim_jupyter.image")
local cell_ui  = require("nvim_jupyter.cell_ui")
local workspace = require("nvim_jupyter.workspace")

-- We'll store the persistent kernel channel here
M.kernel_channel = nil
M.output_buffer  = {}
M.execution_count = 0

-- A unique marker to detect cell execution end
local marker = "<<<END_OF_CELL>>>"

-- Pattern to match IPython prompt lines
local prompt_pattern = "^In %[[0-9]+%]:%s*$"

-- Keep track of active kernels for different notebooks
M.kernels = {}

-- Start the kernel if not running
function M.start_kernel()
  if not M.kernel_channel then
    local kernel_cmd = config.persistent_kernel_cmd or "ipython --simple-prompt --no-banner"
    local bufnr = vim.api.nvim_get_current_buf()
    local file_path = vim.api.nvim_buf_get_name(bufnr)
    
    -- Notify user that kernel is starting
    vim.notify("Starting Jupyter kernel...", vim.log.levels.INFO)
    
    M.kernel_channel = vim.fn.jobstart(kernel_cmd, {
      stdout_buffered = false,
      stderr_buffered = false,
      on_stdout = function(_, data, _)
        for _, line in ipairs(data) do
          if line:find(marker) then
            -- Reached the end marker
            local final_output = {}
            for _, l in ipairs(M.output_buffer) do
              if not l:find(marker) then
                table.insert(final_output, l)
              end
            end
            
            -- Get current notebook to access cell outputs
            local current_nb = cell.current_notebook
            local cell_outputs = nil
            
            -- Try to get the execution count and cell outputs
            local execution_count_match = line:match("In %[(%d+)%]")
            if execution_count_match then
              M.execution_count = tonumber(execution_count_match)
            end
            
            -- Get the current cell index - use protected call since cell_ui may fail
            local _, end_line = cell.get_current_cell_range()
            local bufnr = vim.api.nvim_get_current_buf()
            
            -- Update cell_ui with a protected call
            local cell_ui_loaded, result = pcall(function() 
              local cell_idx = cell_ui.find_cell_at_line(bufnr, end_line)
              if cell_idx then
                cell_ui.set_execution_count(bufnr, cell_idx, M.execution_count)
                cell_ui.set_cell_running(bufnr, cell_idx, false)
                return cell_idx
              end
              return nil
            end)
            
            local cell_index = nil
            if cell_ui_loaded and result then
              cell_index = result
            end
            
            -- Get the cell outputs if available
            if current_nb and current_nb.cells and cell_index then
              if current_nb.cells[cell_index] then
                cell_outputs = current_nb.cells[cell_index].outputs
              end
            end
            
            -- Display output based on config setting
            if config.settings and config.settings.output_style == "split" then
              output.display_in_split(final_output, cell_outputs)
            else
              output.display_output(final_output, cell_outputs)
            end
            
            -- Record execution in workspace with protected call
            pcall(function() workspace.record_execution(file_path) end)
            
            -- Clear output buffer
            M.output_buffer = {}
            
            -- Move to next cell if enabled
            if config.settings and config.settings.move_to_next_cell then
              vim.schedule(function() cell.move_to_next_cell() end)
            end
          elseif line:match(prompt_pattern) then
            -- Extract execution count if present
            local count_match = line:match("In %[(%d+)%]")
            if count_match then
              M.execution_count = tonumber(count_match)
            end
          else
            table.insert(M.output_buffer, line)
          end
        end
      end,
      on_stderr = function(_, data, _)
        for _, line in ipairs(data) do
          if not line:match(prompt_pattern) then
            table.insert(M.output_buffer, line)
          end
        end
      end,
      on_exit = function(_, exit_code, _)
        if exit_code ~= 0 then
          vim.notify("Jupyter kernel exited with code " .. exit_code, vim.log.levels.WARN)
        end
        
        -- Clean up kernel reference
        M.kernels[file_path] = nil
        M.kernel_channel = nil
      end
    })
    
    if M.kernel_channel == 0 then
      vim.notify("Failed to start persistent kernel. Check your config.", vim.log.levels.ERROR)
      return false
    end
    
    -- Register session in workspace
    M.kernels[file_path] = M.kernel_channel
    workspace.register_session(file_path, M.kernel_channel)
    workspace.update_cell_count(file_path)
    
    return true
  end
  
  return true
end

-- Run the current cell
function M.run_current_cell()
  if not M.start_kernel() then
    return
  end

  local start_line, end_line = cell.get_current_cell_range()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local code = table.concat(lines, "\n")
  if code == "" then
    vim.notify("No code to run", vim.log.levels.WARN)
    return
  end
  
  -- Get the current cell index with protected call
  local cell_ui_loaded, cell_idx = pcall(function()
    return cell_ui.find_cell_at_line(bufnr, start_line)
  end)
  
  -- Mark the cell as running
  if cell_ui_loaded and cell_idx then
    pcall(function() cell_ui.set_cell_running(bufnr, cell_idx, true) end)
  end

  -- Append our marker so we know when the cell's done
  local code_to_run = code .. "\nprint('" .. marker .. "')\n"
  
  -- Send code to kernel and notify user
  vim.fn.chansend(M.kernel_channel, code_to_run .. "\n")
  vim.notify("Running cell...", vim.log.levels.INFO)
end

-- Run all cells in the notebook
function M.run_all_cells()
  if not M.start_kernel() then
    return
  end
  
  local bufnr = vim.api.nvim_get_current_buf()
  local cells = cell_ui.scan_buffer_cells(bufnr)
  
  if #cells == 0 then
    vim.notify("No cells found in notebook", vim.log.levels.WARN)
    return
  end
  
  -- Save current position
  local current_pos = vim.api.nvim_win_get_cursor(0)
  
  -- Run each cell in sequence
  for i, cell_data in ipairs(cells) do
    -- Move cursor to the cell
    vim.api.nvim_win_set_cursor(0, {cell_data.line_num, 0})
    
    -- Run the cell
    M.run_current_cell()
    
    -- Wait a bit between cells
    vim.cmd("sleep 100m")
  end
  
  -- Return to original position
  vim.api.nvim_win_set_cursor(0, current_pos)
end

-- Run all cells up to current cell
function M.run_cells_to_cursor()
  if not M.start_kernel() then
    return
  end
  
  local bufnr = vim.api.nvim_get_current_buf()
  local current_pos = vim.api.nvim_win_get_cursor(0)
  local current_line = current_pos[1]
  local cells = cell_ui.scan_buffer_cells(bufnr)
  
  if #cells == 0 then
    vim.notify("No cells found in notebook", vim.log.levels.WARN)
    return
  end
  
  -- Find the current cell index
  local current_cell_idx = nil
  for i, cell_data in ipairs(cells) do
    if current_line >= cell_data.line_num and 
       (i == #cells or current_line < cells[i+1].line_num) then
      current_cell_idx = i
      break
    end
  end
  
  if not current_cell_idx then
    vim.notify("Could not determine current cell", vim.log.levels.WARN)
    return
  end
  
  -- Run cells up to and including the current cell
  for i = 1, current_cell_idx do
    -- Move cursor to the cell
    vim.api.nvim_win_set_cursor(0, {cells[i].line_num, 0})
    
    -- Run the cell
    M.run_current_cell()
    
    -- Wait a bit between cells
    vim.cmd("sleep 100m")
  end
  
  -- Return to original position
  vim.api.nvim_win_set_cursor(0, current_pos)
end

-- Restart the kernel
function M.restart_kernel()
  local bufnr = vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(bufnr)
  
  -- Stop the current kernel
  if M.kernel_channel then
    vim.fn.jobstop(M.kernel_channel)
    M.kernel_channel = nil
    M.kernels[file_path] = nil
  end
  
  -- Clear any output windows
  output.close_all_windows()
  
  -- Start a new kernel
  if M.start_kernel() then
    vim.notify("Jupyter kernel restarted", vim.log.levels.INFO)
  end
end

-- Use our dedicated notebook fixer
local fix_notebook = require("nvim_jupyter.fix_notebook")

-- Function to launch the notebook in a Jupyter server
function M.open_in_jupyter_server()
  local bufnr = vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(bufnr)
  
  -- Check if the current file is a Jupyter notebook
  if not file_path:match("%.ipynb$") then
    vim.notify("Current file is not a Jupyter notebook", vim.log.levels.ERROR)
    return
  end
  
  -- Save the file first to ensure all changes are written
  vim.cmd("write")
  
  -- Try to fix any compatibility issues with the notebook format
  local fixed = fix_notebook.fix_notebook_file(file_path)
  if fixed then
    vim.notify("Fixed notebook format for better compatibility with Jupyter server", vim.log.levels.INFO)
  end
  
  -- Use the directory-based approach which is more reliable
  local notebook_dir = vim.fn.fnamemodify(file_path, ":h")
  
  -- Determine the proper command based on the Jupyter version
  local cmd
  if vim.fn.executable("jupyter-lab") == 1 then
    cmd = "jupyter-lab --notebook-dir=" .. vim.fn.shellescape(notebook_dir)
  else
    cmd = "jupyter notebook --notebook-dir=" .. vim.fn.shellescape(notebook_dir)
  end
  
  -- Notify the user
  vim.notify("Opening Jupyter server in directory: " .. notebook_dir, vim.log.levels.INFO)
  
  -- Launch the Jupyter server in the background
  vim.fn.jobstart(cmd, {
    detach = true,
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        vim.notify("Failed to open Jupyter server (exit code: " .. exit_code .. ")", 
                  vim.log.levels.ERROR)
      end
    end
  })
  
  -- Show information about how to navigate to the notebook
  local notebook_name = vim.fn.fnamemodify(file_path, ":t")
  
  vim.defer_fn(function()
    vim.notify(string.format(
      "Jupyter server starting. Your notebook should be available at:\n" ..
      "http://localhost:8888/notebooks/%s\n" ..
      "Or navigate to it through the Jupyter file browser.", 
      notebook_name), 
      vim.log.levels.INFO)
  end, 2000)
end

-- Register module commands
function M.setup()
  -- Create user commands
  vim.api.nvim_create_user_command('JupyterRunAll', function()
    M.run_all_cells()
  end, {})
  
  vim.api.nvim_create_user_command('JupyterRunToCell', function()
    M.run_cells_to_cursor()
  end, {})
  
  vim.api.nvim_create_user_command('JupyterRestartKernel', function()
    M.restart_kernel()
  end, {})
  
  -- Add command to open in Jupyter server
  vim.api.nvim_create_user_command('JupyterOpenServer', function()
    M.open_in_jupyter_server()
  end, {})
end

return M

