
-- File: lua/nvim_jupyter/runner.lua
local M = {}

local cell   = require("nvim_jupyter.cell")
local output = require("nvim_jupyter.output")
local config = require("nvim_jupyter.config").settings

-- We'll store the persistent kernel channel here
M.kernel_channel = nil
M.output_buffer  = {}

-- A unique marker to detect cell execution end
local marker = "<<<END_OF_CELL>>>"

-- Pattern to match IPython prompt lines
local prompt_pattern = "^In %[[0-9]+%]:%s*$"

-- Start the kernel if not running
function M.start_kernel()
  if not M.kernel_channel then
    local kernel_cmd = config.persistent_kernel_cmd or "ipython --simple-prompt --no-banner"
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
            output.display_output(final_output)
            M.output_buffer = {}
            vim.schedule(function() cell.move_to_next_cell() end)
          elseif line:match(prompt_pattern) then
            -- skip these
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
    })
    if M.kernel_channel == 0 then
      print("Failed to start persistent kernel. Check your config.")
    end
  end
end

-- Run the current cell
function M.run_current_cell()
  M.start_kernel()

  local start_line, end_line = cell.get_current_cell_range()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local code = table.concat(lines, "\n")
  if code == "" then
    print("No code to run")
    return
  end

  -- Append our marker so we know when the cell's done
  local code_to_run = code .. "\nprint('" .. marker .. "')\n"
  vim.fn.chansend(M.kernel_channel, code_to_run .. "\n")
end

return M

