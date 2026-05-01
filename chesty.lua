local w, h = term.getSize()

local chests = {peripheral.find("inventory")}

local itemCounts = {}
for _, chest in ipairs(chests) do
    local items = chest.list()
    for slot, item in pairs(items) do
        local name = item.name:match(":(.+)$") or item.name
        itemCounts[name] = (itemCounts[name] or 0) + item.count
    end
end

local itemList = {}
for name, count in pairs(itemCounts) do
    table.insert(itemList, string.format("%-4dx: %s", count, name))
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