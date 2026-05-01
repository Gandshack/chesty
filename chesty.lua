local w, h = term.getSize()

local chest = peripheral.find("inventory")
local items = chest.list()

local itemList = {}
for slot, item in pairs(items) do
    table.insert(itemList, item.name .. " x" .. item.count)
end

local scrollOffset = 0
local maxScroll = math.max(0, #itemList - h)


local function draw()
    term.clear()
    for y = 1, h do
        local item = itemList[y + scrollOffset]
        term.setCursorPos(1, y)
        if item then
            term.write(item)
        end
    end
end

draw()

while true do
    local event, delta = os.pullEvent("mouse_scroll")
    scrollOffset = math.max(0, math.min(scrollOffset + delta, maxScroll))
    draw()
end