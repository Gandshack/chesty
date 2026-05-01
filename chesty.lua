local w, h = term.getSize()

-- Create windows
local mainWin = window.create(term.current(), 1, 1, w, h - 1)
local cmdWin = window.create(term.current(), 1, h, w, 1)

local CONFIG_FILE = "output.cfg"

-- Find wired modem
local modem
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "modem" and not peripheral.call(name, "isWireless") then
        modem = peripheral.wrap(name)
        break
    end
end

-- Load saved output chest name from disk, if it exists
local function loadOutputName()
    if fs.exists(CONFIG_FILE) then
        local f = fs.open(CONFIG_FILE, "r")
        local name = f.readAll()
        f.close()
        return name
    end
    return nil
end

local function saveOutputName(name)
    local f = fs.open(CONFIG_FILE, "w")
    f.write(name)
    f.close()
end

local outputChestName = loadOutputName()
local outputChest = nil
local chests = {}

-- Build the list of storage chests, excluding the output
local function rebuildChestList()
    chests = {}
    outputChest = nil

    if not modem then return end

    for _, name in ipairs(modem.getNamesRemote()) do
        if peripheral.hasType(name, "inventory") then
            if name == outputChestName then
                outputChest = peripheral.wrap(name)
            else
                table.insert(chests, peripheral.wrap(name))
            end
        end
    end
end

rebuildChestList()

local itemCounts = {}
local itemData = {}
local itemList = {}
local scrollOffset = 0
local maxScroll = 0
local sortMode = "name"

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
        itemList[i] = string.format("%-6dx: %s", entry.count, entry.name)
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

local function status(msg, duration)
    term.redirect(cmdWin)
    term.clear()
    term.setCursorPos(1, 1)
    term.write(msg)
    term.redirect(term.native())
    sleep(duration or 1)
end

local function showHelp()
    term.redirect(mainWin)
    term.clear()
    local lines = {
        "Commands:",
        "  q, quit - Exit program",
        "  help - Show this help",
        "  pull <item> <amount> - Pull items",
        "  push - Push all output items back",
        "  refresh - Rescan all chests",
        "  sort name|count - Sort the list",
        "  find <item> - Filter list by name",
        "  list - Show full list",
        "  chests - List network chests",
        "  perf - List all peripherals",
        "  output - Pick output chest",
        "  how - Setup tutorial",
        "",
        "Press any key to return...",
    }
    for i, line in ipairs(lines) do
        term.setCursorPos(1, i)
        term.write(line)
    end
    term.redirect(term.native())
    os.pullEvent("key")
end

-- List all networked chests with numbers, let user pick one to be the output
local function chooseOutputChest()
    if not modem then
        status("No wired modem found!", 2)
        return
    end

    local allChests = {}
    for _, name in ipairs(modem.getNamesRemote()) do
        if peripheral.hasType(name, "inventory") then
            table.insert(allChests, name)
        end
    end
    table.sort(allChests)

    if #allChests == 0 then
        status("No chests on network!", 2)
        return
    end

    -- Show the list with numbers, support scrolling if too many
    local pickOffset = 0
    local pickMax = math.max(0, #allChests - (h - 2))

    local function drawPicker()
        term.redirect(mainWin)
        term.clear()
        term.setCursorPos(1, 1)
        term.write("Select output chest (type number):")
        for y = 2, h - 1 do
            local idx = y - 1 + pickOffset
            local name = allChests[idx]
            term.setCursorPos(1, y)
            if name then
                local marker = (name == outputChestName) and "*" or " "
                term.write(string.format("%s%2d. %s", marker, idx, name))
            end
        end
        term.redirect(cmdWin)
        term.clear()
        term.setCursorPos(1, 1)
        term.write("Pick #: ")
        term.redirect(term.native())
    end

    drawPicker()

    local input = ""
    while true do
        local event, p1 = os.pullEvent()
        if event == "mouse_scroll" then
            pickOffset = math.max(0, math.min(pickOffset + p1, pickMax))
            drawPicker()
        elseif event == "char" then
            input = input .. p1
            term.redirect(cmdWin)
            term.setCursorPos(1, 1)
            term.clearLine()
            term.write("Pick #: " .. input)
            term.redirect(term.native())
        elseif event == "key" then
            if p1 == keys.enter then
                local n = tonumber(input)
                if n and allChests[n] then
                    outputChestName = allChests[n]
                    saveOutputName(outputChestName)
                    rebuildChestList()
                    scanChests()
                    status("Output set: " .. outputChestName, 2)
                    return
                else
                    status("Invalid number", 1)
                    drawPicker()
                    input = ""
                end
            elseif p1 == keys.backspace then
                input = input:sub(1, -2)
                term.redirect(cmdWin)
                term.setCursorPos(1, 1)
                term.clearLine()
                term.write("Pick #: " .. input)
                term.redirect(term.native())
            elseif p1 == keys.q then
                return
            end
        end
    end
end

-- List ALL peripherals (direct + network), scrollable, * marks output
local function listPeripherals()
    local all = {}
    local seen = {}

    for _, name in ipairs(peripheral.getNames()) do
        if not seen[name] then
            seen[name] = true
            table.insert(all, {name = name, ptype = peripheral.getType(name)})
        end
    end

    if modem then
        for _, name in ipairs(modem.getNamesRemote()) do
            if not seen[name] then
                seen[name] = true
                table.insert(all, {name = name, ptype = peripheral.getType(name) or modem.getTypeRemote(name)})
            end
        end
    end

    table.sort(all, function(a, b) return a.name < b.name end)

    if #all == 0 then
        status("No peripherals found!", 2)
        return
    end

    local perfOffset = 0
    local perfMax = math.max(0, #all - (h - 2))

    local function drawPerf()
        term.redirect(mainWin)
        term.clear()
        term.setCursorPos(1, 1)
        term.write(string.format("All peripherals (%d)  (* = output)", #all))
        for y = 2, h - 1 do
            local idx = y - 1 + perfOffset
            local entry = all[idx]
            term.setCursorPos(1, y)
            if entry then
                local marker = (entry.name == outputChestName) and "*" or " "
                term.write(string.format("%s %s [%s]", marker, entry.name, entry.ptype or "?"))
            end
        end
        term.redirect(cmdWin)
        term.clear()
        term.setCursorPos(1, 1)
        term.write("Scroll or press any key to return...")
        term.redirect(term.native())
    end

    drawPerf()

    while true do
        local event, p1 = os.pullEvent()
        if event == "mouse_scroll" then
            perfOffset = math.max(0, math.min(perfOffset + p1, perfMax))
            drawPerf()
        elseif event == "key" then
            return
        end
    end
end

-- Just list networked chests for inspection
local function listNetworkChests()
    if not modem then
        status("No wired modem found!", 2)
        return
    end

    local allChests = {}
    for _, name in ipairs(modem.getNamesRemote()) do
        if peripheral.hasType(name, "inventory") then
            table.insert(allChests, name)
        end
    end
    table.sort(allChests)

    term.redirect(mainWin)
    term.clear()
    term.setCursorPos(1, 1)
    term.write("Networked chests (* = output):")
    for i, name in ipairs(allChests) do
        if i + 1 > h - 2 then break end -- don't overflow
        term.setCursorPos(1, i + 1)
        local marker = (name == outputChestName) and "*" or " "
        term.write(string.format("%s%2d. %s", marker, i, name))
    end
    term.setCursorPos(1, h - 1)
    term.write("Press any key...")
    term.redirect(term.native())
    os.pullEvent("key")
end

local function pullItem(itemName, amount)
    local data = itemData[itemName]
    if not data then
        status("Item not found!")
        return
    end

    if not outputChestName or not outputChest then
        status("No output set! Use 'output' command", 2)
        return
    end

    local remaining = amount
    for _, loc in ipairs(data.locations) do
        if remaining <= 0 then break end
        local toMove = math.min(remaining, loc.count)
        local moved = loc.chest.pushItems(outputChestName, loc.slot, toMove)
        remaining = remaining - moved
    end

    status("Pulled " .. (amount - remaining) .. "x " .. itemName)
end

local function pushAll()
    if not outputChest then
        status("No output chest set! Use 'output' command", 2)
        return
    end

    local items = outputChest.list()
    if not items then
        status("Output chest is empty or unavailable")
        return
    end

    local total = 0
    for slot, item in pairs(items) do
        for _, chest in ipairs(chests) do
            local moved = outputChest.pushItems(peripheral.getName(chest), slot)
            total = total + moved
            if moved >= item.count then break end
        end
    end

    scanChests()
    status("Pushed " .. total .. " items to storage")
end

local function handleCommand(cmd)
    if cmd == "q" or cmd == "quit" then
        term.clear()
        term.setCursorPos(1, 1)
        return false
    elseif cmd == "help" then
        showHelp()
    elseif cmd == "refresh" then
        rebuildChestList()
        scanChests()
        status("Refreshed! " .. #itemList .. " items found")
    elseif cmd == "chests" then
        listNetworkChests()
    elseif cmd == "perf" then
        listPeripherals()
    elseif cmd == "output" then
        chooseOutputChest()
    elseif cmd:match("^sort ") then
        local mode = cmd:match("^sort (%S+)$")
        if mode == "name" or mode == "count" then
            sortMode = mode
            scanChests()
            status("Sorted by " .. mode)
        else
            status("Usage: sort name|count")
        end
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
            status("Found " .. #itemList .. " matches")
        end
    elseif cmd == "list" then
        scanChests()
    elseif cmd == "how" then
        term.redirect(mainWin)
        term.clear()
        local lines = {
            "=== SETUP TUTORIAL ===",
            "",
            "1. Place a wired modem on this computer",
            "2. Connect modems to each storage chest",
            "3. Right-click each modem to activate it",
            "4. Place a modem on your OUTPUT chest too",
            "5. Run 'output' to pick which chest is",
            "   the output. It will be saved.",
            "",
            "Items pulled with 'pull' will be sent",
            "to the chosen output chest.",
            "",
            "Press any key to return...",
        }
        for i, line in ipairs(lines) do
            term.setCursorPos(1, i)
            term.write(line)
        end
        term.redirect(term.native())
        os.pullEvent("key")
    elseif cmd:match("^pull ") then
        local itemName, amountStr = cmd:match("^pull (%S+) (%d+)$")
        if itemName and amountStr then
            pullItem(itemName, tonumber(amountStr))
        else
            status("Usage: pull <item> <amount>")
        end
    elseif cmd == "push" then
        pushAll()
    end
    return true
end

-- Prompt for output on first run if not set
if not outputChestName then
    status("No output chest configured. Use 'output' to set one.", 2)
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