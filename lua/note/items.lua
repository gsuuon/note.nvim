local util = require('note.util')
local files = require('note.files')

local M = {}

--- @class Position
--- @field row number 0-indexed row
--- @field col number 0-indexed column

--- @class Item
--- @field body string content of the item
--- @field marker string marker character
--- @field position Position start position of the item marker

--- @class Target
--- @field body string pattern to search for
--- @field marker string marker character or marker class

--- @alias LinkTarget
--- | { marker: string }
--- | { marker: string, body: string }
--- | { marker: string, body: string, action: string }

--- @class Link
--- @field start number
--- @field stop number
--- @field file? { path: string, commit?: string }
--- @field link_target? LinkTarget

--- Try to parse a line as an item
--- @param line string
--- @param row number
--- @return Item | nil
function M.parse_item(line, row)
  local indents, marker, body = line:match('^(%s*)([^%s]) (.+)')

  if indents ~= nil then
    return {
      body = body,
      marker = marker,
      position = {
        col = #indents,
        row = row
      }
    }
  end

  -- Section item
  local depth, text = line:match('^(#+) (.+)')

  if depth ~= nil then
    return {
      body = text,
      marker = depth,
      position = {
        col = 0,
        row = row
      }
    }
  end
end

--- Maps over an iterator
--- @param map fun(control, value): any map
--- @param packed_iterator any iterator, can be packed table of an iterator
--- @param stop_at_nil? boolean stop mapping if map returns nil
local function iter_map(map, packed_iterator, stop_at_nil)
  local fn, state, last

  if type(packed_iterator) == 'function' then
    fn = packed_iterator
  else
    fn, state, last = util.tbl_unpack(packed_iterator)
  end
  local control = last

  return function()
    for i, val in fn, state, control do
      control = i
      local result = map(i, val)
      if result ~= nil or stop_at_nil then
        return result
      end
    end
  end
end

--- Iterates items over a packed iterator (e.g. util.tbl_pack(ipairs(lines)))
--- iterator's first return value should be 1-indexed row
--- @param packed_iterator any
--- @return fun(): Item iterator
local function items_from_iter(packed_iterator)
  return iter_map(function(row1, line)
    return M.parse_item(line, row1 - 1)
  end, packed_iterator)
end

--- Iterate over items in lines
--- @return fun(): Item
function M.items(lines)
  return items_from_iter(util.tbl_pack(ipairs(lines)))
end

--- Iterate over children of an item
--- @param parent_item Item parent item
--- @param lines string[] all lines of file
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

--- @return Item | nil
function M.parent(item, lines)
  for row1, line in util.tbl_iter(lines, item.position.row, 0) do
    local x = M.parse_item(line, row1 - 1)
    if x ~= nil and x.position.col < item.position.col then
      return x
    end
  end
end

--- @return Item | nil
function M.get_last_child(parent, lines)
  local last
  for x in M.children(parent, lines) do
    last = x
  end
  return last
end

--- @return Item | nil
function M.find_child(match, parent, lines)
  for child in M.children(parent, lines) do
    if match(child) then
      return child
    end
  end
end

--- @param a Item
--- @param b Item
--- @return number Relative depth of b to a (based on vim.o.sw) - can be float
function M.relative_depth(a, b)
  local diff = b.position.col - a.position.col
  local depth = diff / vim.o.sw
  return depth
end

--- @param item Item
function M.item_as_line(item)
  return
      (' '):rep(item.position.col)
      .. item.marker
      .. ' '
      .. item.body
end

--- @param match fun(item: Item): boolean
--- @param lines string[]
function M.find_item(match, lines)
  for item in M.items(lines) do
    if match(item) then return item end
  end
end

-- Tasks can change markers, e.g. marking `-` pending as `.` done
-- Links with 't' will still work after changing status.
-- Sections can also be linked without specifying exact depth
local link_marker_classes = {
  ['t'] = '[>.,-=]', -- [t]ask
  ['p'] = '[*[]',    -- [p]roperty
  ['s'] = '#+'       -- [s]ection
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

function M.find_target(target, lines)
  return M.find_item(function(item)
    return match_item_target(target, item)
  end, lines)
end

--- Convert a pattern to a case insensitive pattern (a -> [Aa]) and escape dashes
--- @param pat string
local function cannon_pattern(pat)
  return (pat:gsub('(%a)',
    function(l)
      return '[' .. l:upper() .. l:lower() .. ']'
    end
  ):gsub('%-', '%%-'))
end

--- Finds the item first scanning down from row, then up from row.
--- @param target Target
--- @param row number 0-indexed row
--- @param lines string[]
--- @param is_pattern? boolean body is a pattern, do not convert to case sensitive and escape dash
function M.scan_for_item(target, row, lines, is_pattern)
  if not is_pattern then
    target = vim.tbl_extend('force', target, {
      body = cannon_pattern(target.body)
    })
  end

  -- Scan down from row
  local item = find_item_matching_iter(
    target,
    util.tbl_pack(
      util.tbl_iter(lines, row + 1, #lines)
    )
  )
  if item ~= nil then return item end

  if row == 0 then return end
  -- Scan up from row
  item = find_item_matching_iter(
    target,
    util.tbl_pack(
      util.tbl_iter(lines, row, 0)
    )
  )
  if item ~= nil then return item end
end

--- Gets the item under the cursor
--- @return Item | nil
function M.cursor_item()
  local cursor = util.cursor()

  local line = files.line(cursor.row)
  if line == nil then return end

  return M.parse_item(line, cursor.row)
end

--- @param parent Item
--- @param child { marker: string, body: string }
--- @return Item
function M.add_child(parent, child, bufnr)
  local is_section = parent.marker:sub(1, 1) == '#'

  local child_item = vim.tbl_extend('force', child, {
    position = {
      col = (is_section and 0) or parent.position.col + vim.o.sw,
      row = parent.position.row + 1
    }
  })

  M.add_item(child_item, bufnr)

  return child_item
end

--- Add child to parent at end
--- @param parent Item
--- @param child { marker: string, body: string }
--- @param lines string[]
--- @return Item
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

--- @param item Item
--- @param update { marker: string, body: string }
function M.set_item(item, update)
  local item_ = vim.tbl_extend('force', item, update)
  files.set_line(item_.position.row, M.item_as_line(item_))
  return item_
end

--- Inserts item at its position
function M.add_item(item, bufnr)
  files.set_line(
    item.position.row,
    M.item_as_line(item),
    bufnr,
    true
  )
  return item
end

function M.find_or_create_child(parent, child, lines)
  local existing = M.find_child(function(item)
    return item.marker == child.marker and item.body == child.body
  end, parent, lines)

  if existing then
    return existing
  end

  return M.add_child(parent, child)
end

local function parse_link_target(str)
  local marker, body, action = str:match('^([^|]*)|?([^|]*)|?([^|]*)')

  if marker == nil then return end

  return {
    marker = marker,
    body = body,
    action = action
  }
end

---@param str string link string
---@return Link
local function parse_link(str)
  local file_part, target_part = str:match('^%((.+)%)(.*)')

  if file_part == nil then
    return {
      link_target = parse_link_target(str)
    }
  else
    local path, commit = file_part:match('([^@]+)@?(.*)')

    return {
      file = {
        path = path,
        commit = commit
      },
      link_target = parse_link_target(target_part)
    }
  end
end

--- @return { start: number, stop: number, matches: string[] } | nil
local function string_match_at(line, pattern, col)
  -- FIXME this function is pretty awful. multivals are painful.
  local res = { line:find(pattern) }
  local start, stop, group = util.tbl_unpack(res)

  local col1 = col + 1

  while start ~= nil do
    if col1 >= start and col1 <= stop then

      local matches
      if group == nil then -- no capture
        matches = { line:sub(start, stop) }
      else
        matches = { util.tbl_unpack(res, 3) }
      end

      return {
        start = start - 1, -- 1 indexed
        stop = stop, -- inclusive
        matches = matches
      }
    end

    res = { line:find(pattern, stop) }
    start = res[1]
    if start == nil then return end

    stop = res[2]
    group = res[3]
  end
end

--- Finds links in line, returning the one that spans col
--- @param line string
--- @param col number 0-indexed col of line
--- @return Link | nil
function M.get_link_at_col(line, col)
  -- TODO test
  local matched = string_match_at(line, '%{{(.-)%}}', col)

  if matched == nil or matched.matches[1] == nil then return end

  local link = parse_link(matched.matches[1])

  link.start = matched.start
  link.stop = matched.stop

  return link
end

--- Returns a Link as [(file@commit)marker|body|action]
---@param link Link
---@return string 
function M.link_to_str(link)

  local file_part = ''

  if link.file ~= nil then
    file_part = file_part .. '(' .. link.file.path

    if link.file.commit ~= nil then
      file_part = file_part .. '@' .. link.file.commit
    end

    file_part = file_part .. ')'
  end

  local link_part = table.concat(
    vim.tbl_filter(
      function(x)
        return x ~= nil and x ~= ''
      end,
      {
        link.link_target.marker,
        link.link_target.body,
        link.link_target.action,
      }
    ),
    '|'
  )

  return '{{' .. file_part .. link_part .. '}}'
end

return M
