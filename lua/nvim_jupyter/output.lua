
-- File: lua/nvim_jupyter/output.lua

local output = {}
local config = require("nvim_jupyter.config").settings

-- Displays output lines in a floating window.
function output.display_output(lines)
  -- Create a scratch buffer.
  local buf = vim.api.nvim_create_buf(false, true)  -- not listed, scratch buffer
  vim.bo[buf].buftype   = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile  = false

  -- Insert the output lines.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Set a buffer-local keymap: pressing 'q' will close the floating window.
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })

  -- Calculate dimensions for the floating window.
  local width  = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.3)
  local row    = math.floor((vim.o.lines - height) / 2) - 1
  local col    = math.floor((vim.o.columns - width) / 2)

  local opts = {
    style    = "minimal",
    relative = "editor",
    width    = width,
    height   = height,
    row      = row,
    col      = col,
  }

  -- Open the floating window.
  vim.api.nvim_open_win(buf, true, opts)
end

return output

