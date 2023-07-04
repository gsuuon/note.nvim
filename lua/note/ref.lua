local util = require('note.util')
local items = require('note.items')
local files = require('note.files')

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
function M.create_ref_info_item(item, file)
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

---@return string | nil
local function get_item_ref(item, lines)
  local ref_item = items.find_child(function(x)
    return x.marker == '*' and x.body:match('ref:.+')
  end, item, lines)

  if ref_item == nil then return end

  local ref = ref_item.body:match('ref:(.+)')
  return ref
end

---Yank the ref of the item to be used with NoteRefPaste
function M.yank_ref(item, current_file)
  local ref = get_item_ref(item, files.current_lines())
  if ref == nil then return end

  M.saved_ref = {
    ref = ref,
    file = current_file
  }
end

function M.yank_item(item, current_file)
  local ref = get_item_ref(item, files.current_lines())

  if ref == nil then
    ref = M.create_ref_info_item(item, current_file)
  end

  M.saved_item = {
    marker = item.marker,
    body = item.body,
    ref = {
      ref = ref,
      file = current_file
    }
  }
end

---@param item Item | nil
function M.paste_item(item, current_file, root)
  local saved_item = {
    marker = M.saved_item.marker,
    body = M.saved_item.body,
  }

  local added_item
  if item == nil then
    added_item = items.add_item(vim.tbl_extend('force', saved_item, {
      position = util.cursor()
    }))
  else
    added_item = items.add_child(item, saved_item)
  end

  items.add_child(added_item, {
    marker = '*',
    body = create_ref_link(M.saved_item.ref)
  })

  local pasted_ref = M.create_ref_info_item(added_item, current_file)

  vim.cmd.split(files.join_paths({root, M.saved_item.ref.file}))

  local target = {
    marker = '*',
    body = 'ref:' .. M.saved_item.ref.ref
  }

  local lines = files.lines()
  local ref_item = items.find_target(target, lines)

  if ref_item == nil then
    error('Original ref not found: ' .. vim.inspect(M.saved_item.ref))
  end

  local original_item = items.parent(ref_item, lines)
  if original_item == nil then return end

  items.add_child(original_item, {
    marker = '*',
    body = create_ref_link({ref = pasted_ref, file = current_file})
  })
end

return M
