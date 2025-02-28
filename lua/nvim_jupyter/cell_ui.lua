-- File: lua/nvim_jupyter/cell_ui.lua
local cell_ui = {}

-- Store namespace ID for buffer highlights
cell_ui.ns_id = vim.api.nvim_create_namespace("jupyter_cell_highlights")

-- Store cell markers for all buffers
cell_ui.buffer_cells = {}

-- Colors
local colors = {
  -- Even more subtle, professional colors
  code_cell_bg = "#1f1f1f", -- Very subtle dark gray for code cells
  code_border = "#4b6983", -- Muted blue for code cell borders
  markdown_cell_bg = "#1f1f1f", -- Same as code cell - no difference in content
  markdown_border = "#5a7a4f", -- Muted green for markdown cell borders
  active_cell_bg = "#242424", -- Slightly lighter when active
  active_cell_border = "#5e81ac", -- Muted blue when active
  execution_count_bg = "#3b4252", -- Very dark gray for execution count
  running_indicator = "#d08770" -- Muted orange for running indicator
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
  
  -- Function to check if a line looks like a cell marker
  local function is_cell_marker(line)
    -- Original cell markers
    if line:match("^# %%") then
      return true
    end
    
    -- New styled cell headers
    if line:match("^┌─+┐$") or line:match("^╒═+╕$") then
      return true 
    end
    
    -- Hidden markers
    if line:match("^# %% %[hidden%]$") or line:match("^<!%-%- %% %[markdown%] %-%->$") then
      return true
    end
    
    return false
  end
  
  -- First pass - find all cell boundaries
  for i, line in ipairs(lines) do
    -- Look for a sequence of cell header patterns
    if is_cell_marker(line) or 
       (i < #lines - 3 and
        (lines[i]:match("^┌─+┐$") and 
         lines[i+1]:match("^│.*CELL.*│$") and
         lines[i+2]:match("^└─+┘$"))) then
      
      -- Determine cell type
      local cell_type = "code"
      
      -- Check for markdown markers
      if line:match("%[markdown%]") or 
         (i < #lines - 1 and lines[i+1] and lines[i+1]:match("MARKDOWN CELL")) or
         (i < #lines - 3 and lines[i+3] and lines[i+3]:match("<!%-%- %% %[markdown%] %-%->")) then
        cell_type = "markdown"
      end
      
      -- Extract execution count if present in format # %% [X]
      local execution_count = line:match("%[(%d+)%]")
      
      -- For new style headers, scan a few lines to get execution count
      if not execution_count and i < #lines - 5 then
        for j = i, i + 5 do
          if lines[j] and lines[j]:match("%[(%d+)%]") then
            execution_count = lines[j]:match("%[(%d+)%]")
            break
          end
        end
      end
      
      -- Save the cell
      table.insert(cell_ui.buffer_cells[bufnr], {
        line_num = i,
        type = cell_type,
        execution_count = execution_count,
        running = false
      })
      
      -- Skip lines that are part of cell header for the new format
      if lines[i]:match("^┌─+┐$") or lines[i]:match("^╒═+╕$") then
        -- Skip 3 lines (top border, title, bottom border)
        i = i + 3
      end
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
    
    -- Detect if this is a new-style cell with borders
    local is_new_style = false
    local lines = vim.api.nvim_buf_get_lines(bufnr, cell.line_num-1, cell.line_num+2, false)
    if #lines >= 3 and lines[1]:match("^┌─+┐$") and lines[3]:match("^└─+┘$") then
      is_new_style = true
    end
    
    -- Different highlighting for new style cells vs old style
    if is_new_style then
      -- For new style, only highlight the borders and title, not the content
      
      -- Top border
      vim.api.nvim_buf_add_highlight(bufnr, cell_ui.ns_id, border_group, cell.line_num-1, 0, -1)
      
      -- Title line - use a different highlight to make it stand out
      vim.api.nvim_buf_add_highlight(bufnr, cell_ui.ns_id, 
        is_active and "JupyterActiveCellBorder" or highlight_group, 
        cell.line_num, 0, -1)
      
      -- Bottom border
      vim.api.nvim_buf_add_highlight(bufnr, cell_ui.ns_id, border_group, cell.line_num+1, 0, -1)
      
      -- Skip the hidden marker
      
      -- Content area (skip header lines)
      for line = cell.line_num+4, cell.end_line do
        -- For code cells, content gets a subtle highlight
        -- For markdown cells, content remains plain
        if cell.type == "code" or is_active then
          vim.api.nvim_buf_add_highlight(bufnr, cell_ui.ns_id, highlight_group, line-1, 0, -1)
        end
      end
      
      -- Add running indicator if needed
      if cell.running then
        local title_line = vim.api.nvim_buf_get_lines(bufnr, cell.line_num, cell.line_num+1, false)[1]
        vim.api.nvim_buf_add_highlight(bufnr, cell_ui.ns_id, "JupyterRunningIndicator", 
          cell.line_num, string.len(title_line) - 15, string.len(title_line))
      end
      
      -- Highlight execution count if present by adding it to the title line
      if cell.execution_count and cell.type == "code" then
        -- Try to add the execution count to the title line
        local title_line = vim.api.nvim_buf_get_lines(bufnr, cell.line_num, cell.line_num+1, false)[1]
        -- Get position of "CODE CELL"
        local title_pos = title_line:find("CODE CELL")
        if title_pos then
          -- Replace the title with one that includes the execution count
          local new_title_line = title_line:sub(1, title_pos-1) .. 
                               "CODE CELL [" .. cell.execution_count .. "]" .. 
                               title_line:sub(title_pos + 9)
          vim.api.nvim_buf_set_lines(bufnr, cell.line_num, cell.line_num+1, false, {new_title_line})
        end
      end
    else
      -- Old style cells - apply highlight to entire cell including content
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
end

-- Add visual cell borders when opening or creating new cells
function cell_ui.enhance_cell_marker(bufnr, line_num, cell_type)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  -- Create professional cell separator with clear visual distinction
  local width = math.min(vim.api.nvim_win_get_width(0) - 5, 80)
  
  -- Define cell type-specific elements
  local cell_title, border_char, border_color
  if cell_type == "markdown" then
    cell_title = "MARKDOWN CELL"
    border_char = "─"
    border_color = colors.markdown_border
  else
    cell_title = "CODE CELL"
    border_char = "─" 
    border_color = colors.code_border
  end
  
  -- Create a simple, professional header without the "# %%" marker
  local left_padding = math.floor((width - #cell_title - 4) / 2)
  local right_padding = width - #cell_title - 4 - left_padding
  
  local border_line = "┌" .. string.rep(border_char, width - 2) .. "┐"
  local title_line = "│" .. string.rep(" ", left_padding) .. cell_title .. string.rep(" ", right_padding) .. "│"
  local bottom_line = "└" .. string.rep(border_char, width - 2) .. "┘"
  
  -- Insert an empty line for the code to start
  local empty_line = "" -- Truly empty
  
  -- Include a hidden marker for compatibility, but make it a comment with no visual impact
  local hidden_marker
  if cell_type == "markdown" then
    hidden_marker = "<!-- %% [markdown] -->"
  else
    hidden_marker = "# %% [hidden]"
  end
    
  -- Update the line in the buffer
  vim.api.nvim_buf_set_lines(bufnr, line_num-1, line_num, false, {
    border_line, 
    title_line, 
    bottom_line,
    hidden_marker, -- Hidden marker for compatibility with parsing
    empty_line
  })
  
  -- Re-scan and highlight cells
  cell_ui.scan_buffer_cells(bufnr)
  cell_ui.render_highlights(bufnr)
  
  -- Return the number of lines we inserted (so we can adjust cursor position)
  return 5
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