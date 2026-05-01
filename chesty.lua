local w, h = term.getSize()

-- Create windows
local mainWin = window.create(term.current(), 1, 1, w, h - 1)
local cmdWin = window.create(term.current(), 1, h, w, 1)

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
local maxScroll = math.max(0, #itemList - (h - 1))
local cmdInput = ""


local function draw()
    term.redirect(mainWin)
    term.clear()
    for y = 1, h - 1 do
        local item = itemList[y + scrollOffset]
        term.setCursorPos(1, y)
        if item then
            term.write(item)
        end
    end
    
    term.redirect(cmdWin)
    term.clear()
    term.setCursorPos(1, 1)
    term.write(">" .. cmdInput)
    term.redirect(term.native())
end

local function handleCommand(cmd)
    if cmd == "q" or cmd == "quit" then
        term.clear()
        term.setCursorPos(1, 1)
        return false  -- exit
    elseif cmd == "help" then
        term.redirect(cmdWin)
        term.clear()
        term.setCursorPos(1, 1)
        term.write("q=quit, help=this")
        term.redirect(term.native())
        sleep(2)
        return true
    end
    return true  -- continue
end

draw()

while true do
    local event, param1 = os.pullEvent()
    
    if event == "mouse_scroll" then
        scrollOffset = math.max(0, math.min(scrollOffset + param1, maxScroll))
        draw()
        
    elseif event == "char" then
        cmdInput = cmdInput .. param1
        draw()
        
    elseif event == "key" then
        if param1 == keys.enter then
            if not handleCommand(cmdInput) then
                break
            end
            cmdInput = ""
            draw()
        elseif param1 == keys.backspace then
            cmdInput = cmdInput:sub(1, -2)
            draw()
        end
    end
end