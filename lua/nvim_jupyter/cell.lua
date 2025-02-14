
-- File: lua/nvim_jupyter/cell.lua
local cell = {}

-- We'll store the currently loaded .ipynb in memory here.
-- This table will have fields like: nbformat, nbformat_minor, metadata, cells, etc.
cell.current_notebook = nil

------------------------------------------------------------------------------
-- (A) READ: BufReadCmd for *.ipynb
--     1. Read the actual JSON from disk
--     2. Decode JSON
--     3. Store it in cell.current_notebook
--     4. Convert the cells[] to # %% markers, set them into the current buffer
------------------------------------------------------------------------------

-- Called by our BufReadCmd
function cell.load_ipynb()
  local fname = vim.fn.expand("%:p")
  local f = io.open(fname, "r")
  if not f then
    vim.notify("Could not open file: " .. fname, vim.log.levels.ERROR)
    return
  end
  local content = f:read("*a")
  f:close()

  local ok, notebook = pcall(vim.fn.json_decode, content)
  if not ok or type(notebook) ~= "table" then
    vim.notify("Invalid JSON in " .. fname, vim.log.levels.ERROR)
    return
  end

  -- Store the entire notebook in memory
  cell.current_notebook = notebook

  -- Convert the cell array into # %% lines
  local lines = {}
  if notebook.cells then
    for _, c in ipairs(notebook.cells) do
      if c.cell_type == "markdown" then
        table.insert(lines, "# %% [markdown]")
      else
        table.insert(lines, "# %%")
      end
      -- c.source is an array of lines (with newlines) or a single string
      if type(c.source) == "table" then
        for _, s in ipairs(c.source) do
          -- strip trailing newline so we don't double them
          local line_no_nl = s:gsub("\n$", "")
          table.insert(lines, line_no_nl)
        end
      elseif type(c.source) == "string" then
        -- handle the string case
        for s in c.source:gmatch("([^\n]*\n?)") do
          if s ~= "" then
            table.insert(lines, s:gsub("\n$", ""))
          end
        end
      end

      -- Blank line between cells
      table.insert(lines, "")
    end
  end

  -- Wipe the current (empty) buffer and set these lines
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  -- Mark buffer unmodified
  vim.api.nvim_buf_set_option(0, "modified", false)
end

------------------------------------------------------------------------------
-- (B) WRITE: BufWriteCmd for *.ipynb
--     1. We parse # %% markers from the buffer
--     2. We replace `cell.current_notebook.cells` with newly parsed cells
--     3. We write the .ipynb JSON to disk
------------------------------------------------------------------------------

function cell.save_as_ipynb()
  -- We must have read or created the notebook
  if not cell.current_notebook then
    -- If we haven't read an existing notebook, build a fresh one
    cell.current_notebook = {
      nbformat = 4,
      nbformat_minor = 5,
      metadata = {},
      cells = {}
    }
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- We'll parse the # %% lines into a new cell array
  local new_cells = {}
  local current_cell_type = "code"
  local current_source = {}

  local function flush_cell()
    if #current_source > 0 then
      table.insert(new_cells, {
        cell_type = current_cell_type,
        metadata = {},
        execution_count = nil,
        outputs = {}, -- We'll keep original outputs if they exist below
        source = vim.tbl_map(function(s) return s .. "\n" end, current_source),
      })
      current_source = {}
    end
  end

  for _, line in ipairs(lines) do
    if line:match("^# %%") then
      -- Starting a new cell, flush the previous
      flush_cell()
      if line:match("%[markdown%]") then
        current_cell_type = "markdown"
      else
        current_cell_type = "code"
      end
    else
      table.insert(current_source, line)
    end
  end
  -- flush the last cell
  flush_cell()

  -- If we have an old notebook with outputs, let's preserve them
  -- (matching cells by index). If the user changed the cell count,
  -- we won't do fancy matching, just keep them if the count matches.
  if cell.current_notebook.cells then
    for i, c in ipairs(cell.current_notebook.cells) do
      if new_cells[i] and c.outputs then
        new_cells[i].outputs = c.outputs
        new_cells[i].execution_count = c.execution_count
      end
    end
  end

  -- Now put these new cells into our existing notebook structure
  cell.current_notebook.cells = new_cells

  -- Write it out
  local notebook_json = vim.fn.json_encode(cell.current_notebook)
  local fname = vim.fn.expand("%:p")

  local f = io.open(fname, "w")
  if f then
    f:write(notebook_json)
    f:close()
    vim.api.nvim_buf_set_option(bufnr, "modified", false)
    vim.notify("Wrote notebook to " .. fname, vim.log.levels.INFO)
  else
    vim.notify("Error writing file " .. fname, vim.log.levels.ERROR)
  end
end

------------------------------------------------------------------------------
-- (C) Other cell functions: add_cell, get_current_cell_range, move_to_next_cell
------------------------------------------------------------------------------

function cell.add_cell(cell_type)
  local marker = "# %%"
  if cell_type == "markdown" then
    marker = "# %% [markdown]"
  end
  local row = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0, row, row, false, { marker, "" })
  vim.api.nvim_win_set_cursor(0, { row + 2, 0 })
end

function cell.get_current_cell_range()
  local bufnr = vim.api.nvim_get_current_buf()
  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  local cur_line = vim.api.nvim_win_get_cursor(0)[1]
  local start_line, end_line

  for i = cur_line, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
    if line:match("^# %%") then
      start_line = i
      break
    end
  end
  if not start_line then start_line = 1 end

  for i = cur_line + 1, total_lines do
    local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
    if line and line:match("^# %%") then
      end_line = i - 1
      break
    end
  end
  if not end_line then end_line = total_lines end

  return start_line, end_line
end

function cell.move_to_next_cell()
  local bufnr = vim.api.nvim_get_current_buf()
  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  local _, end_line = cell.get_current_cell_range()
  local next_cell_line = nil

  for i = end_line + 1, total_lines do
    local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
    if line and line:match("^# %%") then
      next_cell_line = i
      break
    end
  end

  if next_cell_line then
    vim.api.nvim_win_set_cursor(0, { next_cell_line, 0 })
  end
end

------------------------------------------------------------------------------
-- (D) Setup: define BufReadCmd/BufWriteCmd so we never see raw JSON
------------------------------------------------------------------------------

function cell.setup_autosync()
  local config = require("nvim_jupyter.config").settings
  if config.auto_sync then
    vim.cmd([[
      augroup JupyterRoundTrip
        autocmd!
        " On reading a .ipynb, don't load it normally; call load_ipynb()
        autocmd BufReadCmd *.ipynb lua require("nvim_jupyter.cell").load_ipynb()
        " On writing a .ipynb, call save_as_ipynb() instead of normal write
        autocmd BufWriteCmd *.ipynb lua require("nvim_jupyter.cell").save_as_ipynb()
      augroup END
    ]])
  end
end

function cell.setup()
  -- Create user commands
  vim.api.nvim_create_user_command('JupyterNewCodeCell', function()
    cell.add_cell("code")
  end, {})
  vim.api.nvim_create_user_command('JupyterNewMarkdownCell', function()
    cell.add_cell("markdown")
  end, {})
  vim.api.nvim_create_user_command('JupyterRunCell', function()
    require("nvim_jupyter.runner").run_current_cell()
  end, {})

  cell.setup_autosync()
end

return cell

