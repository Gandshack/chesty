local w, h = term.getSize()

-- Create windows
local mainWin = window.create(term.current(), 1, 1, w, h - 1)
local cmdWin = window.create(term.current(), 1, h, w, 1)

-- Find wired modem to distinguish networked vs local peripherals
local modem
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "modem" and not peripheral.call(name, "isWireless") then
        modem = peripheral.wrap(name)
        break
    end
end

local networkedNames = {}
if modem then
    for _, name in ipairs(modem.getNamesRemote()) do
        networkedNames[name] = true
    end
end

local outputChest = nil
local outputChestName = nil
local chests = {}

for _, name in ipairs(peripheral.getNames()) do
    if peripheral.hasType(name, "inventory") then
        if networkedNames[name] then
            table.insert(chests, peripheral.wrap(name))
        else
            outputChest = peripheral.wrap(name)
            outputChestName = name
        end
    end
end

local itemCounts = {}
local itemData = {}
local itemList = {}
local scrollOffset = 0
local maxScroll = 0
local sortMode = "name"  -- "name" or "count"

local function scanChests()
    itemCounts = {}
    itemData = {}
    itemList = {}

    for chestIdx, chest in ipairs(chests) do
        local items = chest.list()
        if items then
            for slot, item in pairs(items) do
                local parsedName = item.name:match(":(.+)$") or item.name
                itemCounts[parsedName] = (itemCounts[parsedName] or 0) + item.count

                if not itemData[parsedName] then
                    itemData[parsedName] = {fullName = item.name, locations = {}}
                end
                table.insert(itemData[parsedName].locations, {chest = chest, chestIdx = chestIdx, slot = slot, count = item.count})
            end
        end
    end

    for name, count in pairs(itemCounts) do
        table.insert(itemList, {name = name, count = count})
    end

    if sortMode == "name" then
        table.sort(itemList, function(a, b) return a.name < b.name end)
    else
        table.sort(itemList, function(a, b) return a.count > b.count end)
    end

    for i, entry in ipairs(itemList) do
        itemList[i] = string.format("%-4dx: %s", entry.count, entry.name)
    end

    scrollOffset = 0
    maxScroll = math.max(0, #itemList - (h - 1))
end

scanChests()
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
    term.write("  refresh - Rescan all chests")
    term.setCursorPos(1, 6)
    term.write("  sort name|count - Sort the list")
    term.setCursorPos(1, 7)
    term.write("  find <item> - Filter list by name")
    term.setCursorPos(1, 8)
    term.write("  list - Show full list")
    term.setCursorPos(1, 9)
    term.write("  how - Setup tutorial")
    term.setCursorPos(1, 10)
    term.write("")
    term.setCursorPos(1, 11)
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
        term.write("No output chest found!")
        term.redirect(term.native())
        sleep(1)
        return
    end

    local remaining = amount
    for _, loc in ipairs(data.locations) do
        if remaining <= 0 then break end
        local toMove = math.min(remaining, loc.count)
        loc.chest.pushItems(outputChestName, loc.slot, toMove)
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
    elseif cmd == "refresh" then
        scanChests()
        term.redirect(cmdWin)
        term.clear()
        term.setCursorPos(1, 1)
        term.write("Refreshed! " .. #itemList .. " items found")
        term.redirect(term.native())
        sleep(1)
        return true
    elseif cmd:match("^sort ") then
        local mode = cmd:match("^sort (%S+)$")
        if mode == "name" or mode == "count" then
            sortMode = mode
            scanChests()
            term.redirect(cmdWin)
            term.clear()
            term.setCursorPos(1, 1)
            term.write("Sorted by " .. mode)
            term.redirect(term.native())
            sleep(1)
        else
            term.redirect(cmdWin)
            term.clear()
            term.setCursorPos(1, 1)
            term.write("Usage: sort name|count")
            term.redirect(term.native())
            sleep(1)
        end
        return true
    elseif cmd:match("^find ") then
        local query = cmd:match("^find (.+)$")
        if query then
            itemList = {}
            for name, count in pairs(itemCounts) do
                if name:find(query, 1, true) then
                    table.insert(itemList, string.format("%-4dx: %s", count, name))
                end
            end
            scrollOffset = 0
            maxScroll = math.max(0, #itemList - (h - 1))
            term.redirect(cmdWin)
            term.clear()
            term.setCursorPos(1, 1)
            term.write("Found " .. #itemList .. " matches")
            term.redirect(term.native())
            sleep(1)
        end
        return true
    elseif cmd == "list" then
        scanChests()
        return true
    elseif cmd:match("^find ") then
        local query = cmd:match("^find (.+)$")
        if query then
            itemList = {}
            for name, count in pairs(itemCounts) do
                if name:find(query, 1, true) then
                    table.insert(itemList, string.format("%-4dx: %s", count, name))
                end
            end
            scrollOffset = 0
            maxScroll = math.max(0, #itemList - (h - 1))
            term.redirect(cmdWin)
            term.clear()
            term.setCursorPos(1, 1)
            term.write("Found " .. #itemList .. " matches")
            term.redirect(term.native())
            sleep(1)
        end
        return true
    elseif cmd == "list" then
        scanChests()
        return true
    elseif cmd == "how" then
        term.redirect(mainWin)
        term.clear()
        term.setCursorPos(1, 1)
        term.write("=== SETUP TUTORIAL ===")
        term.setCursorPos(1, 3)
        term.write("1. Place a wired modem on this computer")
        term.setCursorPos(1, 4)
        term.write("2. Connect modems to each storage chest")
        term.setCursorPos(1, 5)
        term.write("3. Right-click each modem to activate it")
        term.setCursorPos(1, 6)
        term.write("4. All connected chests will be scanned")
        term.setCursorPos(1, 7)
        term.write("")
        term.setCursorPos(1, 8)
        term.write("Output chest:")
        term.setCursorPos(1, 9)
        term.write("  Place a chest directly ON TOP of")
        term.setCursorPos(1, 10)
        term.write("  the computer. Items from 'pull'")
        term.setCursorPos(1, 11)
        term.write("  will always be sent there.")
        term.setCursorPos(1, 13)
        term.write("Press any key to return...")
        term.redirect(term.native())
        os.pullEvent("key")
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