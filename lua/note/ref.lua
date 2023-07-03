local util = require('note.util')
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

---Adds an info item with ref to target item. If file is provided, then
---pasting the ref link will include filepath
---@param item Item
---@param file? string
---@return string ref
function M.create_ref(item, file)
  local ref = create_ref_id(12)

  items.add_child(item, {
    marker = '*',
    body = 'ref:' .. ref
  })

  M.saved_ref = {
    file = file,
    ref = ref
  }

  return ref
end

-- ref can be a string, nil, or {file, ref}
local function create_ref_link(ref)
  if ref == nil then
    if M.saved_ref == nil then return end

    ref = M.saved_ref
  elseif type(ref) == 'string' then
    ref = {
      ref = ref
    }
  end

  -- [()*|ref:ref]
  local tail = ('*|ref:%s|parent'):format(ref.ref)

  if ref.file then
    return ('[(%s)%s]'):format(ref.file, tail)
  else
    return ('[%s]'):format(tail)
  end
end

function M.insert_ref(ref)
  local ref_link = create_ref_link(ref)

  local pos = util.cursor()

  vim.api.nvim_buf_set_text(
    0,
    pos.row,
    pos.col,
    pos.row,
    pos.col,
    { ref_link }
  )
end

return M
