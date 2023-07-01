local util = require('note.util')
local files = require('note.files')

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

---@class Target
---@field body string pattern to search for
---@field marker string marker character or marker class

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

---@param item_line ItemLine
---@param row number 0-indexed row
function M.itemline_as_item(item_line, row)
  -- TODO refactor to use this in other parts
  return {
    marker = item_line.marker,
    body = item_line.body,
    position = {
      col = item_line.col,
      row = row
    }
  }
end

---Maps over an iterator
---@param map fun(control, value): any map
---@param packed_iterator any iterator, can be packed table of an iterator
---@param stop_at_nil? boolean stop mapping if map returns nil
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

---@return Item | nil
function M.parent(item, lines)
  for row, line in util.tbl_iter(lines, item.position.row, 0) do
    local x = M.line_as_item(line)
    if x ~= nil then
      if x.col < item.position.col then
        return vim.tbl_extend('force', x, {
          position = {
            row = row - 1,
            col = x.col
          }
        })
      end
    end
  end
end

---@return Item | nil
function M.get_last_child(parent, lines)
  local last
  for x in M.children(parent, lines) do
    last = x
  end
  return last
end

---@return Item | nil
function M.find_child(match, parent, lines)
  for child in M.children(parent, lines) do
    if match(child) then
      return child
    end
  end
end

---@param a Item
---@param b Item
---@return number Relative depth of b to a (based on vim.o.sw) - can be float
function M.relative_depth(a, b)
  local diff = b.position.col - a.position.col
  local depth = diff / vim.o.sw
  return depth
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

local function find_item_matching_iter(target, packed_iter_lines)
  for item in items_from_iter(packed_iter_lines) do
    if match_item_target(target, item) then
      return item
    end
  end
end

--- Finds the item first scanning down from row, then up from row.
---@param row number 0-indexed row
function M.scan_for_item(target, row, lines)
  -- Scan down from row
  local item = find_item_matching_iter(
    target,
    table.pack(
      util.tbl_iter(lines, row + 1, #lines)
    )
  )
  if item ~= nil then return item end

  -- Scan up from row
  item = find_item_matching_iter(
    target,
    table.pack(
      util.tbl_iter(lines, row, 0)
    )
  )
  if item ~= nil then return item end
end

--- Gets the item under the cursor
---@return Item | nil
function M.cursor_item()
  local item = M.line_as_item(vim.api.nvim_get_current_line())
  if item == nil then return end

  return vim.tbl_extend('force', item, {
    position = {
      col = item.col,
      row = util.cursor().row
    }
  })
end

---@param parent Item
---@param child { marker: string, body: string }
---@return Item
function M.add_child(parent, child)
  local child_item = vim.tbl_extend('force', child, {
    position = {
      col = parent.position.col + vim.o.sw,
      row = parent.position.row + 1
    }
  })

  M.add_item(child_item)

  return child_item
end

---Add child to parent at end
---@param parent Item
---@param child { marker: string, body: string }
---@param lines string[]
---@return Item
function M.add_last_child(parent, child, lines)
  local last = M.get_last_child(parent, lines)
  if last == nil then
    return M.add_child(parent, child)
  else
    return M.add_item({
      body = child.body,
      marker = child.marker,
      position = {
        row = last.position.row + 1,
        col = parent.position.col + vim.o.sw
      }
    })
  end
end

---@param item Item
---@param update { marker: string, body: string }
function M.set_item(item, update)
  local item_ = vim.tbl_extend('force', item, update)
  files.set_line(item_.position.row, M.item_as_line(item_))
  return item_
end

---Inserts item at its position
function M.add_item(item)
  files.set_line(
    item.position.row,
    M.item_as_line(item),
    nil,
    true
  )
  return item
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

return M
