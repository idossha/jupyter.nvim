-- File: lua/nvim_jupyter/fix_notebook.lua
-- Purpose: Fix notebook format issues for better compatibility

local M = {}

-- Fix a notebook file to ensure it's fully compatible with Jupyter
function M.fix_notebook_file(file_path)
  -- Read the file
  local f = io.open(file_path, "r")
  if not f then
    vim.notify("Could not open file: " .. file_path, vim.log.levels.ERROR)
    return false
  end
  
  local content = f:read("*all")
  f:close()
  
  -- Try to decode the JSON
  local status, notebook = pcall(vim.fn.json_decode, content)
  if not status or type(notebook) ~= "table" then
    vim.notify("Invalid JSON in " .. file_path, vim.log.levels.ERROR)
    return false
  end
  
  -- Check for problems and fix them
  local needs_fix = false
  
  -- Fix top-level metadata
  if type(notebook.metadata) == "table" and vim.tbl_islist(notebook.metadata) then
    notebook.metadata = {}
    needs_fix = true
  end
  
  -- Ensure basic notebook structure
  if not notebook.nbformat then
    notebook.nbformat = 4
    needs_fix = true
  end
  
  if not notebook.nbformat_minor then
    notebook.nbformat_minor = 5
    needs_fix = true
  end
  
  -- Fix cells
  if notebook.cells then
    for _, cell in ipairs(notebook.cells) do
      -- Fix cell metadata
      if type(cell.metadata) == "table" and vim.tbl_islist(cell.metadata) then
        cell.metadata = {}
        needs_fix = true
      end
      
      -- Ensure execution_count exists
      if cell.execution_count == nil then
        cell.execution_count = null
        needs_fix = true
      end
      
      -- Ensure outputs exist and are array
      if cell.outputs == nil then
        cell.outputs = {}
        needs_fix = true
      end
      
      -- Ensure source is an array of strings
      if type(cell.source) ~= "table" or not vim.tbl_islist(cell.source) then
        -- Convert string source to array
        if type(cell.source) == "string" then
          local lines = {}
          for line in cell.source:gmatch("([^\n]*\n?)") do
            table.insert(lines, line)
          end
          cell.source = lines
          needs_fix = true
        else
          -- Create empty source
          cell.source = {""}
          needs_fix = true
        end
      end
    end
  end
  
  -- If we found issues, write the fixed notebook back
  if needs_fix then
    -- Convert to proper JSON
    local fixed_content = vim.fn.json_encode(notebook)
    
    -- Write back to file
    f = io.open(file_path, "w")
    if not f then
      vim.notify("Could not write to file: " .. file_path, vim.log.levels.ERROR)
      return false
    end
    
    f:write(fixed_content)
    f:close()
    
    vim.notify("Fixed notebook format in " .. file_path, vim.log.levels.INFO)
    return true
  end
  
  return false
end

-- Fix the current buffer
function M.fix_current_notebook()
  local bufnr = vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(bufnr)
  
  -- Check if the current file is a notebook
  if not file_path:match("%.ipynb$") then
    vim.notify("Current file is not a Jupyter notebook", vim.log.levels.ERROR)
    return false
  end
  
  -- Save current buffer first
  vim.cmd("write")
  
  -- Fix the file
  local fixed = M.fix_notebook_file(file_path)
  
  -- Reload the buffer if fixed
  if fixed then
    vim.cmd("edit!")
    return true
  end
  
  return false
end

return M