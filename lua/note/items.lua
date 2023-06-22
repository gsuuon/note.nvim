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

--- Iterate over items in lines
---@return fun(): Item
local function items(lines)
  local current_line_idx = 0

  return function()
    local item

    while item == nil and current_line_idx < #lines do
      current_line_idx = current_line_idx + 1
      item = M.line_as_item(lines[current_line_idx])
    end

    if item ~= nil then
      return {
        body = item.body,
        marker = item.marker,
        position = {
          row = current_line_idx - 1,
          col = item.col
        }
      }
    end
  end
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
local function find_item(match, lines)
  for item in items(lines) do
    if match(item) then return item end
  end
end

--- Get link at column of line
---@param line string
---@param col number 0-indexed col of line
---@return { marker: string, body: string, col: number }
function M.get_link_at_col(line, col)
  local start, stop = line:find('%[.-|.-%]')
  col = col + 1

  while start ~= nil do
    if col >= start and col <= stop then
      local marker, body =
        line:sub(start, stop):match('%[(.-)|(.-)%]')

      return {
        marker = marker,
        body = body,
        col = start - 1
      }
    end

    start, stop = line:find('%[.+|.+%]', stop)
  end
end

-- Items can change markers, e.g. marking `-` pending as `.` done
-- Links with 'i' will still work after changing status.
-- Titles can also be linked without specifying exact depth
local link_marker_classes = {
  ['i'] = '[>.,-=]',  -- [i]tem
  ['p'] = '[*[]',     -- [p]roperty
  ['t'] = '#+'
}

---@param target { marker: string, body: string }
---@return Item | nil
function M.find_item_matching(target, lines)
  return find_item(
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
