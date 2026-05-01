local w, h = term.getSize()

-- Create a virtual window for the chesty interface
local virtualWindow = window.create(term.current(), 1, 1, w, h)

local chest = peripheral.find("inventory")
local items = chest.list()

-- Display items to the virtual window
for slot, item in pairs(items) do
    virtualWindow.setCursorPos(1, slot)
    virtualWindow.write(item.name .. " x" .. item.count)
end

-- Main loop to keep the interface responsive
while true do
    -- Handle Scroll 
    local event, side, x, y = os.pullEvent("mouse_scroll")
    if event == "mouse_scroll" then
        -- Scroll the virtual window content based on the scroll direction
        if y > 0 then
            virtualWindow.scroll(-1) -- Scroll up
        elseif y < 0 then
            virtualWindow.scroll(1) -- Scroll down
        end
    end
end
