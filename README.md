What each module does:

init.lua:
Loads and combines all submodules, offering a simple setup() interface for users.

config.lua:
Provides default configuration (for example, which Python command to run, output window height, etc.) and lets users override settings.

cell.lua:
Implements commands to create new cells (code or markdown), sets up syntax highlighting (using a marker like # %%), and provides helper functions (e.g. to detect the current cell’s boundaries).

runner.lua:
Extracts the current cell’s content and executes it. It uses Neovim’s asynchronous job API to run the cell’s code (e.g. via Python) and then collects output.

output.lua:
Creates (or reuses) a split window at the bottom of your editor where cell output is shown. You can later extend this module to provide richer output formatting.
