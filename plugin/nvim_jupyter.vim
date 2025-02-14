
if exists('g:loaded_nvim_jupyter')
  finish
endif
let g:loaded_nvim_jupyter = 1

lua require("nvim_jupyter").setup()
