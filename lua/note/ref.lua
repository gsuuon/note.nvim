local items = require('note.items')

local M = {}

math.randomseed(os.clock())

local chars = {
  '0',
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z'
}

local function create_ref_id(length)
  local res = ''

  for _=1,length,1 do
    local idx = math.random(1, 36)
    res = res .. chars[idx]
  end

  return res
end

--- Adds an info item with ref to target item
---@return string ref
function M.create_ref(item)
  local ref = create_ref_id(12)

  items.add_child(item, {
    marker = '*',
    body = 'ref:' .. ref
  })
  return ref
end

return M
