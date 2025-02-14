
# nvim_jupyter

A **NeoVim plugin** that lets you read, write, and run Jupyter notebooks. You’ll work with notebook cells as simple `# %%` markers, while on disk it’s a real `.ipynb` that opens in VS Code or Jupyter.

## Features

- **Round-Trip Conversion**:  
  - Opening a `.ipynb` reads the JSON and shows `# %%` lines for each cell.  
  - Saving writes a standard `.ipynb` file (with metadata and outputs preserved).  
- **Cell Execution**:  
  - Use a persistent IPython kernel to execute cells in-place.  
  - View outputs in a floating window or split.  
- **Convenient Commands**:  
  - `:JupyterNewCodeCell` or `<leader>jc` inserts a new code cell marker.  
  - `:JupyterNewMarkdownCell` or `<leader>jm` inserts a new markdown cell marker.  
  - `:JupyterRunCell` or `<leader>jr` runs the current cell.  

## Installation

Use your preferred plugin manager, for example with **lazy.nvim**:

```lua
{
  "YourUser/nvim_jupyter",
  config = function()
    require("nvim_jupyter").setup({
      -- Optional overrides
      persistent_kernel_cmd = "ipython --simple-prompt --no-banner",
      auto_sync = true,
    })
  end
}

