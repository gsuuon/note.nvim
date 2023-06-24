local util = require('note.util')

local M = {}

---@class Position
---@field row number 0-indexed row
---@field col number 0-indexed column

---@class ItemLine
---@field body string content of the item
---@field marker string marker character
---@field col number start col of the item marker

---@class Item
---@field body string content of the item
---@field marker string marker character
---@field position Position start position of the item marker

--- Try to parse a line as an item
---@param line string
---@return ItemLine | nil
function M.line_as_item(line)
  local indents, marker, body = line:match('^(%s*)([^%s]) (.+)')

  if indents ~= nil then
    return {
      body = body,
      marker = marker,
      col = #indents
    }
  end

  -- Section item
  local depth, text = line:match('^(#+) (.+)')

  if depth ~= nil then
    return {
      body = text,
      marker = depth,
      col = 0
    }
  end
end

---Maps over an iterator
---@param map fun(control, value): any map
---@param iterator any iterator, can be packed table of an iterator
---@param stop_at_nil boolean stop mapping if map returns nil
local function iter_map(map, packed_iterator, stop_at_nil)
  local fn, state, last

  if type(packed_iterator) == 'function' then
    fn = packed_iterator
  else
    fn, state, last = table.unpack(packed_iterator)
  end
  local control = last

  return function ()
    for i, val in fn, state, control do
      control = i
      local result = map(i, val)
      if result ~= nil or stop_at_nil then
        return result
      end
    end
  end
end

---Iterates items over a packed iterator (e.g. table.pack(ipairs(lines)))
---@param packed_iterator any
---@return fun(): Item iterator
local function items_from_iter(packed_iterator)
  return iter_map(function(row, line)
    local item = M.line_as_item(line)
    if item ~= nil then
      return {
        body = item.body,
        marker = item.marker,
        position = {
          row = row - 1,
          col = item.col
        }
      }
    end
  end, packed_iterator)
end

---Iterate over items in lines
---@return fun(): Item
function M.items(lines)
  return items_from_iter(table.pack(ipairs(lines)))
end

---Iterate over children of an item
---@param parent_item Item parent item
---@param lines string[] all lines of file
function M.children(parent_item, lines)
  local start_row = parent_item.position.row + 1

  return iter_map(
    function(item)
      if item.position.col > parent_item.position.col then
        return item
      end
    end,
    items_from_iter(
      util.tbl_iter(lines, start_row, #lines)
    ),
    true
  )
end

---@param item ItemLine | Item
function M.item_as_line(item)
  return
    (' '):rep(item.col or item.position.col)
    .. item.marker
    .. ' '
    .. item.body
end

---@param match fun(item: Item): boolean
---@param lines string[]
function M.find_item(match, lines)
  for item in M.items(lines) do
    if match(item) then return item end
  end
end

--- Finds the item first scanning down from row, then up from row.
---@param row number 0-indexed row
function M.scan_for_item(target, row, lines)
  -- Scan down from row
  local item = M.find_item_matching_iter(
    target,
    table.pack(
      util.tbl_iter(lines, row + 1, #lines)
    )
  )
  if item ~= nil then return item end

  -- Scan up from row
  item = M.find_item_matching_iter(
    target,
    table.pack(
      util.tbl_iter(lines, row, 0)
    )
  )
  if item ~= nil then return item end
end

--- Get link at column of line
---@param line string
---@param col number 0-indexed col of line
---@return { marker: string, body: string, col: number, file?: string } | nil
function M.get_link_at_col(line, col)
  local start, stop = line:find('%[.-|.-%]')
  col = col + 1

  while start ~= nil do
    if col >= start and col <= stop then
      local head, body = line:sub(start, stop):match('%[(.-)|(.-)%]')

      local _, file_stop, file = head:find('%((.+)%)')
      local marker = head:match('.+', file_stop and file_stop + 1 or 1)

      return {
        marker = marker,
        file = file,
        body = body,
        col = start - 1
      }
    end

    start, stop = line:find('%[.+|.+%]', stop)
  end
end

-- Tasks can change markers, e.g. marking `-` pending as `.` done
-- Links with 't' will still work after changing status.
-- Sections can also be linked without specifying exact depth
local link_marker_classes = {
  ['t'] = '[>.,-=]',  -- [t]ask
  ['p'] = '[*[]',     -- [p]roperty
  ['s'] = '#+'        -- [s]ection
}

local function match_item_target(target, item)
  local marker_match_pattern = link_marker_classes[target.marker]

  local marker_matches =
  marker_match_pattern ~= nil
  and item.marker:match(marker_match_pattern)
  or item.marker == target.marker

  if not marker_matches then return false end

  return item.body:match(target.body)
end

function M.find_item_matching_iter(target, packed_iter_lines)
  for item in items_from_iter(packed_iter_lines) do
    if match_item_target(target, item) then
      return item
    end
  end
end

return M
