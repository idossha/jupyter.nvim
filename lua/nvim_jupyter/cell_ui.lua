-- File: lua/nvim_jupyter/cell_ui.lua
local cell_ui = {}

-- Store namespace ID for buffer highlights
cell_ui.ns_id = vim.api.nvim_create_namespace("jupyter_cell_highlights")

-- Store cell markers for all buffers
cell_ui.buffer_cells = {}

-- Flag to control visual rendering (enabled by default)
cell_ui.visual_enabled = true

-- Colors
local colors = {
  -- Border colors only - no background highlights
  code_border = "#4b6983", -- Muted blue for code cell borders
  markdown_border = "#5a7a4f", -- Muted green for markdown cell borders
  active_border = "#5e81ac", -- Muted blue when active
  execution_count_bg = "#3b4252", -- Very dark gray for execution count
  running_indicator = "#d08770" -- Muted orange for running indicator
}

-- Create highlight groups
function cell_ui.setup_highlights()
  -- Border highlights only - no background colors
  vim.cmd("highlight default JupyterCodeCellBorder guifg=" .. colors.code_border .. " gui=bold")
  vim.cmd("highlight default JupyterMarkdownCellBorder guifg=" .. colors.markdown_border .. " gui=bold")
  vim.cmd("highlight default JupyterActiveCellBorder guifg=" .. colors.active_border .. " gui=bold")
  
  -- Empty background highlights (transparent)
  vim.cmd("highlight default JupyterCodeCell guibg=NONE")
  vim.cmd("highlight default JupyterMarkdownCell guibg=NONE")
  vim.cmd("highlight default JupyterActiveCell guibg=NONE")
  
  -- Execution and running indicators
  vim.cmd("highlight default JupyterExecutionCount guibg=" .. colors.execution_count_bg .. " guifg=#ffffff gui=bold")
  vim.cmd("highlight default JupyterRunningIndicator guifg=" .. colors.running_indicator .. " gui=bold")
  
  -- Create a highlight group to hide the actual "# %%" markers
  -- This uses the background color to effectively hide the text
  local bg_color = vim.fn.synIDattr(vim.fn.hlID("Normal"), "bg#")
  if bg_color and bg_color ~= "" then
    vim.cmd("highlight default JupyterHiddenMarker guifg=" .. bg_color)
  else
    -- Fallback if we can't get the background color
    vim.cmd("highlight default JupyterHiddenMarker guifg=#000000 gui=nocombine")
  end
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
  
  -- First pass - find all cell boundaries (only looking for # %% markers)
  for i, line in ipairs(lines) do
    -- Look only for # %% markers - simplify the detection
    if line:match("^# %%") then      
      -- Determine cell type
      local cell_type = line:match("%[markdown%]") and "markdown" or "code"
      
      -- Extract execution count if present in format # %% [X]
      local execution_count = line:match("%[(%d+)%]")
      
      -- Save the cell
      table.insert(cell_ui.buffer_cells[bufnr], {
        line_num = i,
        type = cell_type,
        execution_count = execution_count,
        running = false,
        original_marker = line -- Save original marker for reference
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

-- Store namespace ID for virtual text
cell_ui.virt_text_ns = vim.api.nvim_create_namespace("jupyter_cell_virtual_text")

-- Render cell highlights and borders
function cell_ui.render_highlights(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not cell_ui.buffer_cells[bufnr] then
    cell_ui.scan_buffer_cells(bufnr)
  end
  
  -- Clear existing highlights and virtual text
  cell_ui.clear_highlights(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, cell_ui.virt_text_ns, 0, -1)
  
  -- If visual rendering is disabled, exit early
  if not cell_ui.visual_enabled then
    return
  end
  
  -- Get cursor position to highlight active cell
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local cursor_line = cursor_pos[1]
  local active_cell = cell_ui.find_cell_at_line(bufnr, cursor_line)
  
  -- Check if we're in insert mode - we'll handle active cells differently
  local is_insert_mode = vim.api.nvim_get_mode().mode:match("i")
  
  -- Get editor width for borders
  local width = vim.api.nvim_win_get_width(0) - 1
  
  -- Add highlights and virtual text for all cells
  for _, cell in ipairs(cell_ui.buffer_cells[bufnr]) do
    local is_active = active_cell and cell.line_num == active_cell.line_num
    local highlight_group, border_group, title_text
    
    -- Determine highlight groups based on cell type and active state
    if cell.type == "markdown" then
      -- Markdown cells always use markdown colors, even when active
      highlight_group = "JupyterMarkdownCell"
      border_group = "JupyterMarkdownCellBorder"
    elseif is_active then
      highlight_group = "JupyterActiveCell"
      border_group = "JupyterActiveCellBorder"
    else
      highlight_group = "JupyterCodeCell"
      border_group = "JupyterCodeCellBorder"
    end
    
    -- Define title based on cell type and execution count
    if cell.type == "markdown" then
      title_text = "MARKDOWN CELL"
    else
      title_text = cell.execution_count 
        and string.format("CODE CELL [%s]", cell.execution_count)
        or "CODE CELL"
    end
    
    -- Skip visual rendering for active cell in insert mode
    if is_active and is_insert_mode then
      -- In insert mode, only hide the marker, don't add borders for active cell
      vim.api.nvim_buf_add_highlight(bufnr, cell_ui.ns_id, "JupyterHiddenMarker", cell.line_num - 1, 0, -1)
      
      -- Still apply subtle highlighting to content
      for line = cell.line_num + 1, cell.end_line do
        vim.api.nvim_buf_add_highlight(bufnr, cell_ui.ns_id, highlight_group, line - 1, 0, -1)
      end
    else
      -- Normal visualization for non-active cells or active cell in normal mode
      
      -- Add virtual text (overlay) to replace the "# %%" with a nice border
      -- Top border (full width)
      local top_border = "┌" .. string.rep("─", width - 2) .. "┐"
      vim.api.nvim_buf_set_extmark(bufnr, cell_ui.virt_text_ns, cell.line_num - 1, 0, {
        virt_text = {{top_border, border_group}},
        virt_text_pos = "overlay",
        hl_mode = "combine",
      })
      
      -- Title line (middle)
      local left_padding = math.floor((width - #title_text - 2) / 2)
      local right_padding = width - #title_text - 2 - left_padding
      local title_line = "│" .. string.rep(" ", left_padding) .. title_text .. string.rep(" ", right_padding) .. "│"
      
      -- Add the title as virtual text
      vim.api.nvim_buf_set_extmark(bufnr, cell_ui.virt_text_ns, cell.line_num - 1, 0, {
        virt_text = {{title_line, border_group}},
        virt_text_pos = "eol",
        hl_mode = "combine",
      })
      
      -- Bottom border (full width, added after the marker line)
      local bottom_border = "└" .. string.rep("─", width - 2) .. "┘"
      vim.api.nvim_buf_set_extmark(bufnr, cell_ui.virt_text_ns, cell.line_num - 1, 0, {
        virt_text = {{bottom_border, border_group}},
        virt_text_pos = "right_align",
        hl_mode = "combine",
      })
      
      -- Hide the actual "# %%" marker line
      vim.api.nvim_buf_add_highlight(bufnr, cell_ui.ns_id, "JupyterHiddenMarker", cell.line_num - 1, 0, -1)
      
      -- Add cell running indicator if needed
      if cell.running then
        -- Add a running indicator at the end of the title line
        vim.api.nvim_buf_set_extmark(bufnr, cell_ui.virt_text_ns, cell.line_num - 1, 0, {
          virt_text = {{"[RUNNING]", "JupyterRunningIndicator"}},
          virt_text_pos = "right_align",
          hl_mode = "combine",
        })
      end
      
      -- No background highlighting for cell content - we only want borders
      -- We're keeping this comment as a placeholder in case we want to add highlighting in the future
    end
  end
end

-- Add visual cell borders when opening or creating new cells
function cell_ui.enhance_cell_marker(bufnr, line_num, cell_type)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  -- Create the actual marker that will be added to the file
  local marker
  if cell_type == "markdown" then
    marker = "# %% [markdown]"
  else
    marker = "# %%"
  end
  
  -- Insert only the actual marker in the file (no visual elements)
  vim.api.nvim_buf_set_lines(bufnr, line_num-1, line_num, false, {marker, ""})
  
  -- Re-scan and highlight cells
  cell_ui.scan_buffer_cells(bufnr)
  cell_ui.render_highlights(bufnr)
  
  -- Return number of lines added (marker + empty line)
  return 2
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
      autocmd WinScrolled *.ipynb lua require("nvim_jupyter.cell_ui").render_highlights()
      autocmd VimResized *.ipynb lua require("nvim_jupyter.cell_ui").render_highlights()
      
      " Update visual rendering when switching between insert and normal mode
      autocmd InsertEnter *.ipynb lua require("nvim_jupyter.cell_ui").render_highlights()
      autocmd InsertLeave *.ipynb lua require("nvim_jupyter.cell_ui").render_highlights()
    augroup END
  ]])
end

-- Toggle visual rendering of cells
function cell_ui.toggle_visual_rendering()
  cell_ui.visual_enabled = not cell_ui.visual_enabled
  
  -- Force refresh all open Jupyter notebook buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name:match("%.ipynb$") then
        -- Check if buffer is loaded
        if vim.api.nvim_buf_is_loaded(buf) then
          -- If rendering is enabled, show the cells
          if cell_ui.visual_enabled then
            cell_ui.scan_buffer_cells(buf)
            cell_ui.render_highlights(buf)
          else
            -- If disabled, clear any existing highlights
            cell_ui.clear_highlights(buf)
            vim.api.nvim_buf_clear_namespace(buf, cell_ui.virt_text_ns, 0, -1)
          end
        end
      end
    end
  end
  
  -- Notify the user of the change
  local status = cell_ui.visual_enabled and "enabled" or "disabled"
  vim.notify("Jupyter cell visual rendering " .. status, vim.log.levels.INFO)
  
  return cell_ui.visual_enabled
end

-- Initialize cell UI
function cell_ui.setup()
  cell_ui.setup_highlights()
  cell_ui.setup_autocmds()
  
  -- Create user command for toggling visual rendering
  vim.api.nvim_create_user_command('JupyterToggleVisual', function()
    cell_ui.toggle_visual_rendering()
  end, {})
end

return cell_ui