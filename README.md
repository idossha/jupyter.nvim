# Jupyter.nvim

A professional **Jupyter notebook interface** for Neovim that lets you edit, run, and visualize Jupyter notebooks with advanced features. Work with notebook cells using enhanced visual representation while maintaining compatibility with standard `.ipynb` files.

![Jupyter.nvim Demo](https://github.com/yourusername/jupyter.nvim/raw/main/assets/demo.gif)

## Features

### Core Functionality
- **Round-Trip Conversion**: 
  - Opening a `.ipynb` reads JSON and shows visually enhanced cells
  - Saving writes a standard `.ipynb` file with all metadata and outputs preserved
  - Work in a code-friendly format in Neovim but keep full compatibility with Jupyter

### Enhanced UI
- **Visual Cell Representation**:
  - Distinct styling for code and markdown cells
  - Colorful cell borders and backgrounds
  - Execution count display integrated into cell markers
  - Active cell highlighting

- **Rich Output Display**:
  - Floating windows or split view for cell outputs
  - Support for inline images in terminals that support it (iTerm2, Kitty, WezTerm)
  - External image viewer fallback for other terminals

- **Workspace Management**:
  - Workspace panel showing all active notebooks and kernels
  - Quick switching between open notebooks
  - Execution statistics and monitoring

### Cell Operations
- **Cell Execution**:
  - Execute individual cells, all cells, or cells up to cursor
  - Persistent IPython kernel for fast execution
  - Visual indicator for currently running cells

- **Cell Navigation**:
  - Quickly move between cells
  - Add new code or markdown cells with visual borders

## Installation

Use your preferred plugin manager:

### [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{
  "yourusername/jupyter.nvim",
  config = function()
    require("nvim_jupyter").setup({
      -- Optional configuration
    })
  end,
  dependencies = {
    -- No external dependencies required!
  }
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)
```lua
use {
  'yourusername/jupyter.nvim',
  config = function()
    require('nvim_jupyter').setup()
  end
}
```

## Configuration

### Default Configuration
```lua
require('nvim_jupyter').setup({
  -- Jupyter kernel settings
  python_cmd = "python3",
  persistent_kernel_cmd = "ipython --simple-prompt --no-banner",
  
  -- UI settings
  output_height = 15,
  output_style = "float",   -- "float" or "split"
  move_to_next_cell = true, -- Move to next cell after execution
  auto_sync = true,         -- Automatically handle .ipynb custom save
  enable_cell_borders = true,
  enable_images = true,
  
  -- Keymaps
  keymaps = {
    add_code_cell     = { key = "<leader>jc", desc = "Add a new code cell below cursor" },
    add_markdown_cell = { key = "<leader>jm", desc = "Add a new markdown cell below cursor" },
    run_cell          = { key = "<leader>jr", desc = "Run the current cell" },
    run_all_cells     = { key = "<leader>ja", desc = "Run all cells in the notebook" },
    run_to_cell       = { key = "<leader>jt", desc = "Run all cells until current cell" },
    move_next_cell    = { key = "<leader>jn", desc = "Move cursor to the next cell" },
    move_prev_cell    = { key = "<leader>jp", desc = "Move cursor to the previous cell" },
    restart_kernel    = { key = "<leader>jk", desc = "Restart Jupyter kernel" },
    open_workspace    = { key = "<leader>jw", desc = "Open the Jupyter workspace panel" },
    toggle_output     = { key = "<leader>jo", desc = "Toggle between float/split output display" },
  },
})
```

## Commands

Jupyter.nvim provides several user commands:

- `:JupyterNewCodeCell` - Create a new code cell at cursor position
- `:JupyterNewMarkdownCell` - Create a new markdown cell at cursor position
- `:JupyterRunCell` - Run the current cell
- `:JupyterRunAll` - Run all cells in the notebook
- `:JupyterRunToCell` - Run all cells up to and including the current cell
- `:JupyterRestartKernel` - Restart the Jupyter kernel
- `:JupyterWorkspace` - Open the workspace panel
- `:JupyterKeymapHelp` - Show a help window with all keymaps and descriptions

## Keyboard Shortcuts

Type `:JupyterKeymapHelp` to see all available keyboard shortcuts in a floating window, or check the configuration section above.

## Requirements

- Neovim 0.5.0+
- Python with IPython installed (`pip install ipython`)

## Image Support

For inline images to display properly, you need one of the following terminals:

- **[Kitty](https://sw.kovidgoyal.net/kitty/)** - Fast terminal with built-in image support
- **[iTerm2](https://iterm2.com/)** - macOS terminal with imgcat support
- **[WezTerm](https://wezfurlong.org/wezterm/)** - Cross-platform terminal with image protocol

For other terminals, images will be saved to a temporary file and opened with an external viewer if available.

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.