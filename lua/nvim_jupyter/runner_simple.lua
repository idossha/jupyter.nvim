
-- File: lua/nvim_jupyter/runner.lua

local runner = {}
local cell = require("nvim_jupyter.cell")
local output = require("nvim_jupyter.output")
local config = require("nvim_jupyter.config").settings

-- Extracts the current cell’s content as a single string.
local function get_current_cell_content()
  local start_line, end_line = cell.get_current_cell_range()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
  return table.concat(lines, "\n")
end

-- Run the current cell asynchronously.
function runner.run_current_cell()
  local code = get_current_cell_content()
  if code == "" then
    print("No code to run")
    return
  end

  -- Write cell code to a temporary file.
  local tmpfile = os.tmpname() .. ".py"
  local f = io.open(tmpfile, "w")
  f:write(code)
  f:close()

  local cmd = config.python_cmd .. " " .. tmpfile
  local stdout = {}
  local stderr = {}

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          table.insert(stdout, line)
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          table.insert(stderr, line)
        end
      end
    end,
    on_exit = function(_, exit_code)
      os.remove(tmpfile)
      local output_lines = {}
      if #stdout > 0 then
        vim.list_extend(output_lines, stdout)
      end
      if #stderr > 0 then
        table.insert(output_lines, "Errors:")
        vim.list_extend(output_lines, stderr)
      end

      -- Use our floating output window to display the results.
      output.display_output(output_lines)

      -- After displaying output, schedule moving to the next cell.
      vim.schedule(function()
        cell.move_to_next_cell()
      end)
    end,
  })
end

return runner

