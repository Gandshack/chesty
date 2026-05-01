local w, h = term.getSize()

-- Create windows
local mainWin = window.create(term.current(), 1, 1, w, h - 1)
local cmdWin = window.create(term.current(), 1, h, w, 1)

local chests = {peripheral.find("inventory")}
local outputChest = peripheral.wrap("top")

local itemCounts = {}
local itemData = {}  -- stores {parsedName, fullName, chestIndex, slots}
for chestIdx, chest in ipairs(chests) do
    local items = chest.list()
    for slot, item in pairs(items) do
        local parsedName = item.name:match(":(.+)$") or item.name
        itemCounts[parsedName] = (itemCounts[parsedName] or 0) + item.count
        
        if not itemData[parsedName] then
            itemData[parsedName] = {fullName = item.name, locations = {}}
        end
        table.insert(itemData[parsedName].locations, {chest = chest, chestIdx = chestIdx, slot = slot, count = item.count})
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

local function showHelp()
    term.redirect(mainWin)
    term.clear()
    term.setCursorPos(1, 1)
    term.write("Commands:")
    term.setCursorPos(1, 2)
    term.write("  q, quit - Exit program")
    term.setCursorPos(1, 3)
    term.write("  help - Show this help")
    term.setCursorPos(1, 4)
    term.write("  pull <item> <amount> - Pull items")
    term.setCursorPos(1, 5)
    term.write("")
    term.setCursorPos(1, 6)
    term.write("Press any key to return...")
    term.redirect(term.native())
    os.pullEvent("key")
end

local function pullItem(itemName, amount)
    local data = itemData[itemName]
    if not data then
        term.redirect(cmdWin)
        term.clear()
        term.setCursorPos(1, 1)
        term.write("Item not found!")
        term.redirect(term.native())
        sleep(1)
        return
    end
    
    if not outputChest then
        term.redirect(cmdWin)
        term.clear()
        term.setCursorPos(1, 1)
        term.write("No chest on top!")
        term.redirect(term.native())
        sleep(1)
        return
    end
    
    local remaining = amount
    for _, loc in ipairs(data.locations) do
        if remaining <= 0 then break end
        local toMove = math.min(remaining, loc.count)
        loc.chest.pushItems("top", loc.slot, toMove)
        remaining = remaining - toMove
    end
    
    term.redirect(cmdWin)
    term.clear()
    term.setCursorPos(1, 1)
    term.write("Pulled " .. (amount - remaining) .. "x " .. itemName)
    term.redirect(term.native())
    sleep(1)
end

local function handleCommand(cmd)
    if cmd == "q" or cmd == "quit" then
        term.clear()
        term.setCursorPos(1, 1)
        return false  -- exit
    elseif cmd == "help" then
        showHelp()
        return true
    elseif cmd:match("^pull ") then
        local itemName, amountStr = cmd:match("^pull (%S+) (%d+)$")
        if itemName and amountStr then
            pullItem(itemName, tonumber(amountStr))
        else
            term.redirect(cmdWin)
            term.clear()
            term.setCursorPos(1, 1)
            term.write("Usage: pull <item> <amount>")
            term.redirect(term.native())
            sleep(1)
        end
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