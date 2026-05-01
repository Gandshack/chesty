local chest = peripheral.find("inventory")
local items = chest.list()
for slot, item in pairs(items) do
  print(slot, item.name, item.count)
end