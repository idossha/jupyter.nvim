-- File: lua/nvim_jupyter/image.lua
local image = {}

-- Detect if we're using a terminal that supports image protocol
function image.check_terminal_support()
  local term = os.getenv("TERM")
  local has_kitty = os.getenv("KITTY_WINDOW_ID") ~= nil
  local has_iterm = os.getenv("ITERM_SESSION_ID") ~= nil
  local has_wezterm = os.getenv("WEZTERM_PANE") ~= nil
  
  return has_kitty or has_iterm or has_wezterm
end

-- Convert base64 to file
function image.base64_to_file(base64_data, output_path)
  local success, file = pcall(io.open, output_path, "wb")
  if not success or not file then
    vim.notify("Failed to create temporary image file", vim.log.levels.ERROR)
    return false
  end
  
  -- Decode and write
  local decoded = vim.fn.system("echo '" .. base64_data .. "' | base64 -d")
  file:write(decoded)
  file:close()
  
  return true
end

-- Render image using terminal protocols or external viewers based on availability
function image.render_image(image_data, mime_type)
  local image_path = vim.fn.tempname() .. "." .. mime_type:match("image/(%w+)")
  
  -- Convert base64 data to file
  if not image.base64_to_file(image_data, image_path) then
    return false
  end
  
  -- Try terminal rendering first if supported
  if image.check_terminal_support() then
    -- Kitty terminal graphics protocol
    if os.getenv("KITTY_WINDOW_ID") then
      vim.fn.system("kitty +kitten icat " .. image_path)
      return true
    end
    
    -- iTerm2 image protocol
    if os.getenv("ITERM_SESSION_ID") then
      vim.fn.system("imgcat " .. image_path)
      return true
    end
    
    -- WezTerm image protocol
    if os.getenv("WEZTERM_PANE") then
      -- WezTerm protocol implementation would go here
      -- Currently a placeholder as it depends on specific methods
      return true
    end
  end
  
  -- Fallback to external viewer
  local viewers = {"feh", "imgcat", "display", "open"}
  for _, viewer in ipairs(viewers) do
    if vim.fn.executable(viewer) == 1 then
      vim.fn.jobstart(viewer .. " " .. image_path, {detach = true})
      return true
    end
  end
  
  -- No viewers available, just show the path
  vim.notify("Image saved at: " .. image_path, vim.log.levels.INFO)
  return false
end

-- Extracts and renders images from notebook cell outputs
function image.process_output_images(outputs)
  local rendered_images = 0
  
  if not outputs then return rendered_images end
  
  for _, output_item in ipairs(outputs) do
    if output_item.output_type == "display_data" or output_item.output_type == "execute_result" then
      if output_item.data then
        -- Check for various image formats
        for mime, data in pairs(output_item.data) do
          if mime:match("^image/") then
            if image.render_image(data, mime) then
              rendered_images = rendered_images + 1
            end
          end
        end
      end
    end
  end
  
  return rendered_images
end

return image