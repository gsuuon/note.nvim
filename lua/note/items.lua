local util = require('note.util')

local M = {}

---@class Position
---@field row number 0-indexed row
---@field col number 0-indexed column

---@class ItemLine
---@field body string content of the item
---@field marker string marker character
---@field col number start col of the item marker

--- Try to parse a line as an item
---@param line string
---@return ItemLine | nil
function M.line_as_item(line)
  local indents, marker, body = line:match('^(%s*)(.) (.+)')

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

---@class Item
---@field body string content of the item
---@field marker string marker character
---@field position Position start position of the item marker

---Iterates items over a packed iterator (e.g. table.pack(ipairs(lines)))
---@param packed_iterator any
---@return function iterator
local function items_from_iter(packed_iterator)
  local fn, state, last = table.unpack(packed_iterator)
  local control = last

  return function ()
    for row, line in fn, state, control do
      control = row

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
    end
  end
end

---Iterate over items in lines
---@return fun(): Item
local function items(lines)
  return items_from_iter(table.pack(ipairs(lines)))
end
---@param item ItemLine
function M.item_as_line(item)
  return
    (' '):rep(item.col)
    .. item.marker
    .. ' '
    .. item.body
end

---@param match fun(item: Item): boolean
---@param lines string[]
function M.find_item(match, lines)
  for item in items(lines) do
    if match(item) then return item end
  end
end

--- Finds the item first scanning down from row, then up from row.
---@param row number 0-indexed row
function M.scan_for_item(target, row, lines)
  local after_lines = util.tbl_slice(lines, row + 1, #lines)

  local item = M.find_item_matching(target, after_lines)
  if item ~= nil then
    return vim.tbl_extend('force', item, {
      position = {
        row = item.position.row + row + 1,
        col = item.position.col
      }
    })
  end

  local before_lines = util.tbl_slice(lines, row, 0, true) -- reverse
  item = M.find_item_matching(target, before_lines)
  if item ~= nil then
    return vim.tbl_extend('force', item, {
      position = {
        row = row - item.position.row - 1,
        col = item.position.col
      }
    })
  end
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

---@param target { marker: string, body: string }
---@return Item | nil
function M.find_item_matching(target, lines)
  return M.find_item(
    function(item)
      local marker_match_pattern = link_marker_classes[target.marker]

      local marker_matches =
      marker_match_pattern ~= nil
      and item.marker:match(marker_match_pattern)
      or item.marker == target.marker

      if not marker_matches then return false end

      return item.body:match(target.body)
    end,
    lines
  )
end

return M
