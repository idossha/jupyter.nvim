
-- Plugin entry point: load submodules and expose a setup() function.
local M = {}

M.config = require("nvim_jupyter.config")
M.cell   = require("nvim_jupyter.cell")
M.runner = require("nvim_jupyter.runner")
M.output = require("nvim_jupyter.output")


function M.setup(user_config)
  M.config.setup(user_config or {})  -- Always call setup even if user_config is nil
  M.cell.setup()
end

return M
