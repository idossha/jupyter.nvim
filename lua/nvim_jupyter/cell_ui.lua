-- File: lua/nvim_jupyter/cell_ui.lua
local cell_ui = {}

-- Store namespace ID for buffer highlights
cell_ui.ns_id = vim.api.nvim_create_namespace("jupyter_cell_highlights")

-- Store cell markers for all buffers
cell_ui.buffer_cells = {}

-- Colors
local colors = {
  -- More subtle background colors
  code_cell_bg = "#1a1a1a", -- Almost black, more professional look
  code_border = "#3465a4", -- Blue border for code
  markdown_cell_bg = "#1c1c1c", -- Slightly different black for markdown
  markdown_border = "#73d216", -- Green border for markdown
  active_cell_bg = "#242424", -- Slightly lighter when active
  active_cell_border = "#729fcf", -- Light blue when active
  execution_count_bg = "#555753", -- Dark gray for execution count
  running_indicator = "#f57900" -- Orange for running indicator
}

-- Create highlight groups
function cell_ui.setup_highlights()
  vim.cmd("highlight default JupyterCodeCellBorder guifg=" .. colors.code_border .. " gui=bold")
  vim.cmd("highlight default JupyterCodeCell guibg=" .. colors.code_cell_bg)
  vim.cmd("highlight default JupyterMarkdownCellBorder guifg=" .. colors.markdown_border .. " gui=bold")
  vim.cmd("highlight default JupyterMarkdownCell guibg=" .. colors.markdown_cell_bg)
  vim.cmd("highlight default JupyterActiveCell guibg=" .. colors.active_cell_bg)
  vim.cmd("highlight default JupyterActiveCellBorder guifg=" .. colors.active_cell_border .. " gui=bold")
  vim.cmd("highlight default JupyterExecutionCount guibg=" .. colors.execution_count_bg .. " guifg=#ffffff gui=bold")
  vim.cmd("highlight default JupyterRunningIndicator guifg=" .. colors.running_indicator .. " gui=bold")
end

-- Parse and store all cell boundaries in the current buffer
function cell_ui.scan_buffer_cells(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not cell_ui.buffer_cells[bufnr] then
    cell_ui.buffer_cells[bufnr] = {}
  end
  
  -- Clear existing cell data
  cell_ui.buffer_cells[bufnr] = {}
  
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for i, line in ipairs(lines) do
    if line:match("^# %%") then
      local cell_type = line:match("%[markdown%]") and "markdown" or "code"
      
      -- Extract execution count if present in format # %% [X]
      local execution_count = line:match("%[(%d+)%]")
      
      table.insert(cell_ui.buffer_cells[bufnr], {
        line_num = i,
        type = cell_type,
        execution_count = execution_count,
        running = false
      })
    end
  end
  
  -- Calculate end lines for each cell
  for i, cell in ipairs(cell_ui.buffer_cells[bufnr]) do
    if i < #cell_ui.buffer_cells[bufnr] then
      cell.end_line = cell_ui.buffer_cells[bufnr][i+1].line_num - 1
    else
      cell.end_line = #lines
    end
  end
  
  return cell_ui.buffer_cells[bufnr]
end

-- Find the cell that contains the given line
function cell_ui.find_cell_at_line(bufnr, line_num)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not cell_ui.buffer_cells[bufnr] then
    cell_ui.scan_buffer_cells(bufnr)
  end
  
  for i, cell in ipairs(cell_ui.buffer_cells[bufnr]) do
    if line_num >= cell.line_num and line_num <= cell.end_line then
      return cell, i
    end
  end
  
  return nil
end

-- Clear highlights in buffer
function cell_ui.clear_highlights(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, cell_ui.ns_id, 0, -1)
end

-- Set cell as running
function cell_ui.set_cell_running(bufnr, cell_idx, is_running)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not cell_ui.buffer_cells[bufnr] or not cell_ui.buffer_cells[bufnr][cell_idx] then
    return
  end
  
  cell_ui.buffer_cells[bufnr][cell_idx].running = is_running
  cell_ui.render_highlights(bufnr)
end

-- Set cell execution count
function cell_ui.set_execution_count(bufnr, cell_idx, count)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not cell_ui.buffer_cells[bufnr] or not cell_ui.buffer_cells[bufnr][cell_idx] then
    return
  end
  
  cell_ui.buffer_cells[bufnr][cell_idx].execution_count = count
  
  -- Update the marker line in the buffer
  local cell = cell_ui.buffer_cells[bufnr][cell_idx]
  local line = vim.api.nvim_buf_get_lines(bufnr, cell.line_num-1, cell.line_num, false)[1]
  
  -- Replace or add execution count
  local updated_line
  if cell.type == "markdown" then
    updated_line = line  -- Don't add execution count to markdown cells
  else
    -- If line already has an execution count, replace it
    if line:match("%[%d+%]") then
      updated_line = line:gsub("%[%d+%]", "[" .. count .. "]")
    else
      -- Otherwise add the execution count after the # %% marker
      updated_line = line:gsub("^# %%", "# %% [" .. count .. "]")
    end
  end
  
  vim.api.nvim_buf_set_lines(bufnr, cell.line_num-1, cell.line_num, false, {updated_line})
  
  -- Refresh cell data
  cell_ui.scan_buffer_cells(bufnr)
  cell_ui.render_highlights(bufnr)
end

-- Render cell highlights and borders
function cell_ui.render_highlights(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not cell_ui.buffer_cells[bufnr] then
    cell_ui.scan_buffer_cells(bufnr)
  end
  
  -- Clear existing highlights
  cell_ui.clear_highlights(bufnr)
  
  -- Get cursor position to highlight active cell
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local cursor_line = cursor_pos[1]
  local active_cell = cell_ui.find_cell_at_line(bufnr, cursor_line)
  
  -- Add highlights for all cells
  for _, cell in ipairs(cell_ui.buffer_cells[bufnr]) do
    local is_active = active_cell and cell.line_num == active_cell.line_num
    local highlight_group
    local border_group
    
    if is_active then
      highlight_group = "JupyterActiveCell"
      border_group = "JupyterActiveCellBorder"
    elseif cell.type == "markdown" then
      highlight_group = "JupyterMarkdownCell"
      border_group = "JupyterMarkdownCellBorder"
    else
      highlight_group = "JupyterCodeCell"
      border_group = "JupyterCodeCellBorder"
    end
    
    -- Highlight the cell background
    for line = cell.line_num, cell.end_line do
      vim.api.nvim_buf_add_highlight(bufnr, cell_ui.ns_id, highlight_group, line-1, 0, -1)
    end
    
    -- Add cell border (first line)
    local border_line = vim.api.nvim_buf_get_lines(bufnr, cell.line_num-1, cell.line_num, false)[1]
    
    -- Add running indicator if needed
    if cell.running then
      vim.api.nvim_buf_add_highlight(bufnr, cell_ui.ns_id, "JupyterRunningIndicator", 
        cell.line_num-1, string.len(border_line) + 1, string.len(border_line) + 10)
    end
    
    -- Highlight execution count if present
    if cell.execution_count and cell.type == "code" then
      local start_idx = border_line:find("%[" .. cell.execution_count .. "%]")
      if start_idx then
        vim.api.nvim_buf_add_highlight(bufnr, cell_ui.ns_id, "JupyterExecutionCount", 
          cell.line_num-1, start_idx-1, start_idx + string.len("[" .. cell.execution_count .. "]"))
      end
    end
    
    -- Highlight the border marker
    vim.api.nvim_buf_add_highlight(bufnr, cell_ui.ns_id, border_group, cell.line_num-1, 0, -1)
  end
end

-- Add visual cell borders when opening or creating new cells
function cell_ui.enhance_cell_marker(bufnr, line_num, cell_type)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local marker = "# %%"
  if cell_type == "markdown" then
    marker = "# %% [markdown]"
  end
  
  -- Create professional cell separator with clear visual distinction
  local width = math.min(vim.api.nvim_win_get_width(0) - 5, 80)
  
  -- Create a more distinct cell marker
  local border_top = "╒" .. string.rep("═", width - 3) .. "╕"
  local border_bottom = "╘" .. string.rep("═", width - 3) .. "╛"
  
  -- Insert the border lines and cell marker
  local cell_marker = marker
  if cell_type == "code" then
    cell_marker = marker .. " [Code Cell]"
  else
    cell_marker = marker .. " [Markdown]"
  end
  
  -- Update the line in the buffer
  vim.api.nvim_buf_set_lines(bufnr, line_num-1, line_num, false, {border_top, cell_marker, border_bottom})
  
  -- Re-scan and highlight cells
  cell_ui.scan_buffer_cells(bufnr)
  cell_ui.render_highlights(bufnr)
  
  -- Return the number of lines we inserted (so we can adjust cursor position)
  return 3
end

-- Setup autocommands for cell highlighting
function cell_ui.setup_autocmds()
  vim.cmd([[
    augroup JupyterCellHighlights
      autocmd!
      autocmd BufEnter *.ipynb lua require("nvim_jupyter.cell_ui").scan_buffer_cells()
      autocmd BufEnter *.ipynb lua require("nvim_jupyter.cell_ui").render_highlights()
      autocmd CursorMoved *.ipynb lua require("nvim_jupyter.cell_ui").render_highlights()
      autocmd TextChanged,TextChangedI *.ipynb lua require("nvim_jupyter.cell_ui").scan_buffer_cells()
      autocmd TextChanged,TextChangedI *.ipynb lua require("nvim_jupyter.cell_ui").render_highlights()
    augroup END
  ]])
end

-- Initialize cell UI
function cell_ui.setup()
  cell_ui.setup_highlights()
  cell_ui.setup_autocmds()
end

return cell_ui