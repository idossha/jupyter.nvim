-- File: lua/nvim_jupyter/workspace.lua
local workspace = {}

-- Store active jupyter kernels and notebook session info
workspace.sessions = {}
workspace.current_session = nil

-- UI components
workspace.win_id = nil
workspace.buf_id = nil

-- Store workspace variables
workspace.variables = {}

-- Add a new notebook session to workspace
function workspace.register_session(file_path, kernel_id)
  local session = {
    file_path = file_path,
    kernel_id = kernel_id,
    name = vim.fn.fnamemodify(file_path, ":t"),
    buffer = vim.fn.bufnr(file_path),
    started_at = os.time(),
    cell_count = 0,
    last_run = nil
  }
  
  workspace.sessions[file_path] = session
  workspace.current_session = file_path
  
  return session
end

-- Update cell count for a session
function workspace.update_cell_count(file_path)
  if not workspace.sessions[file_path] then return end
  
  local bufnr = vim.fn.bufnr(file_path)
  if bufnr == -1 then return end
  
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local count = 0
  
  for _, line in ipairs(lines) do
    if line:match("^# %%") then
      count = count + 1
    end
  end
  
  workspace.sessions[file_path].cell_count = count
end

-- Record cell execution
function workspace.record_execution(file_path)
  if not workspace.sessions[file_path] then return end
  workspace.sessions[file_path].last_run = os.time()
end

-- Format time for display
local function format_time(timestamp)
  if not timestamp then return "Never" end
  local diff = os.difftime(os.time(), timestamp)
  
  if diff < 60 then
    return "Just now"
  elseif diff < 3600 then
    return math.floor(diff / 60) .. "m ago"
  else
    return math.floor(diff / 3600) .. "h ago"
  end
end

-- Collect workspace variables from the kernel
function workspace.collect_variables(kernel_id)
  -- Initialize variables for this kernel if not already done
  if not workspace.variables[kernel_id] then
    workspace.variables[kernel_id] = {}
  end
  
  -- Skip if no kernel is active
  if not kernel_id or vim.fn.jobwait({kernel_id}, 0)[1] ~= -1 then
    return
  end
  
  -- Run %who command in the kernel to get a list of variables
  vim.fn.chansend(kernel_id, "%who_ls\nprint('<<<VARIABLES_END>>>')\n")
  
  -- Variables will be collected asynchronously by the kernel's stdout handler
end

-- Function to be called by the runner when variables are received
function workspace.update_variables(kernel_id, var_output)
  if not workspace.variables[kernel_id] then
    workspace.variables[kernel_id] = {}
  end
  
  -- Clear variable details first (keeping any type information)
  for k, _ in pairs(workspace.variables[kernel_id]) do
    workspace.variables[kernel_id][k].value = nil
  end
  
  -- Process output from %who_ls
  if var_output and #var_output > 0 then
    -- Extract the variable names (should be a Python list)
    local var_str = table.concat(var_output, "\n")
    
    -- Try to extract the variable names (format: ['var1', 'var2', ...])
    local var_list = var_str:match("%[(.-)%]")
    if var_list then
      for var_name in var_list:gmatch("'([^']+)'") do
        -- Register the variable
        if not workspace.variables[kernel_id][var_name] then
          workspace.variables[kernel_id][var_name] = {
            name = var_name,
            type = "Unknown"
          }
        end
      end
    end
  end
  
  -- Now fetch type information for each variable
  for var_name, _ in pairs(workspace.variables[kernel_id]) do
    -- Send commands to get variable type
    local cmd = string.format(
      "try:\n" ..
      "    print(f\"'%s': {type(%s).__name__}\")\n" ..
      "except:\n" ..
      "    print(\"'%s': Unknown\")\n", 
      var_name, var_name, var_name)
    
    vim.fn.chansend(kernel_id, cmd)
  end
end

-- Process variable type information received from kernel
function workspace.process_variable_type(kernel_id, line)
  if not workspace.variables[kernel_id] then return end
  
  -- Format should be: 'var_name': type_name
  local var_name, var_type = line:match("'([^']+)':%s*(.+)")
  if var_name and var_type and workspace.variables[kernel_id][var_name] then
    workspace.variables[kernel_id][var_name].type = var_type
  end
end

-- Create and show workspace UI
function workspace.show_ui()
  if workspace.win_id and vim.api.nvim_win_is_valid(workspace.win_id) then
    vim.api.nvim_win_close(workspace.win_id, true)
    workspace.win_id = nil
    return
  end
  
  -- Create buffer if needed
  if not workspace.buf_id or not vim.api.nvim_buf_is_valid(workspace.buf_id) then
    workspace.buf_id = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(workspace.buf_id, 'bufhidden', 'wipe')
  end
  
  -- Update variables for the current session
  if workspace.current_session and workspace.sessions[workspace.current_session] then
    local kernel_id = workspace.sessions[workspace.current_session].kernel_id
    if kernel_id then
      workspace.collect_variables(kernel_id)
    end
  end
  
  -- Prepare content
  local lines = {
    "📓 Jupyter Workspace",
    "══════════════════════════════════════",
    ""
  }
  
  local has_sessions = false
  for path, session in pairs(workspace.sessions) do
    has_sessions = true
    table.insert(lines, (workspace.current_session == path and "▶ " or "  ") .. session.name)
    table.insert(lines, string.format("  • Cells: %d | Last run: %s", 
                                     session.cell_count, 
                                     format_time(session.last_run)))
    
    -- Add variables for this session if available
    if session.kernel_id and workspace.variables[session.kernel_id] then
      local vars = workspace.variables[session.kernel_id]
      local var_count = 0
      for _ in pairs(vars) do var_count = var_count + 1 end
      
      if var_count > 0 then
        table.insert(lines, "  • Variables:")
        
        -- Sort variables alphabetically
        local var_names = {}
        for name, _ in pairs(vars) do
          table.insert(var_names, name)
        end
        table.sort(var_names)
        
        -- Add each variable
        for _, name in ipairs(var_names) do
          local var = vars[name]
          table.insert(lines, string.format("    - %s (%s)", var.name, var.type or "Unknown"))
        end
      end
    end
    
    table.insert(lines, "  ──────────────────────────────────")
  end
  
  if not has_sessions then
    table.insert(lines, "  No active notebook sessions")
    table.insert(lines, "")
    table.insert(lines, "  Open a .ipynb file to start a session")
  end
  
  table.insert(lines, "")
  table.insert(lines, "Press 'q' to close, Enter to switch to notebook")
  
  -- Set content
  vim.api.nvim_buf_set_lines(workspace.buf_id, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(workspace.buf_id, 'modifiable', false)
  
  -- Set buffer-local keymaps
  local opts = { noremap = true, silent = true }
  vim.api.nvim_buf_set_keymap(workspace.buf_id, 'n', 'q', 
    '<cmd>lua require("nvim_jupyter.workspace").close_ui()<CR>', opts)
  vim.api.nvim_buf_set_keymap(workspace.buf_id, 'n', '<CR>', 
    '<cmd>lua require("nvim_jupyter.workspace").select_notebook()<CR>', opts)
  
  -- Create floating window
  local width = math.min(60, vim.o.columns - 4)
  local height = math.min(#lines, vim.o.lines - 4)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' Jupyter Workspace ',
    title_pos = 'center'
  }
  
  workspace.win_id = vim.api.nvim_open_win(workspace.buf_id, true, win_opts)
  
  -- Set window options for better appearance
  vim.api.nvim_win_set_option(workspace.win_id, 'cursorline', true)
  vim.api.nvim_win_set_option(workspace.win_id, 'winblend', 10)
  
  -- Set window-local highlights
  vim.cmd("highlight JupyterWorkspaceHeader guifg=#7DCFFF gui=bold")
  vim.cmd("highlight JupyterWorkspaceBorder guifg=#565f89")
  vim.cmd("highlight JupyterWorkspaceActive guifg=#9ECE6A gui=bold")
  
  -- Apply highlights with matchadd()
  vim.fn.matchadd('JupyterWorkspaceHeader', '^📓 Jupyter Workspace$')
  vim.fn.matchadd('JupyterWorkspaceHeader', '^══════════════════════════════════════$')
  vim.fn.matchadd('JupyterWorkspaceBorder', '^  ──────────────────────────────────$')
  vim.fn.matchadd('JupyterWorkspaceActive', '^▶ .*$')
end

-- Close workspace UI
function workspace.close_ui()
  if workspace.win_id and vim.api.nvim_win_is_valid(workspace.win_id) then
    vim.api.nvim_win_close(workspace.win_id, true)
    workspace.win_id = nil
  end
end

-- Select notebook from UI
function workspace.select_notebook()
  local cursor_pos = vim.api.nvim_win_get_cursor(workspace.win_id)
  local line = vim.api.nvim_buf_get_lines(workspace.buf_id, cursor_pos[1]-1, cursor_pos[1], false)[1]
  
  -- If the line starts with "▶ " or "  " followed by a notebook name
  local notebook_name = line:match("^[▶%s]%s(.+)$")
  
  if notebook_name then
    -- Find the corresponding notebook path
    for path, session in pairs(workspace.sessions) do
      if session.name == notebook_name then
        workspace.close_ui()
        -- Switch to the notebook buffer
        vim.api.nvim_command('buffer ' .. session.buffer)
        return
      end
    end
  end
end

-- Initialize workspace module
function workspace.setup()
  vim.api.nvim_create_user_command('JupyterWorkspace', function()
    workspace.show_ui()
  end, {})
end

return workspace