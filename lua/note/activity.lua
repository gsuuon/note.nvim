local items = require('note.items')
local util  = require('note.util')
local files = require('note.files')

local M     = {}

local function add_activity_timestamp(item, lines, child)
  local activity = items.find_child(function(x)
    return x.marker == '*' and x.body == 'activity' and items.relative_depth(item, x) == 1
  end, item, lines)

  if activity == nil then
    activity = items.add_child(item, {
      marker = '*',
      body = 'activity'
    })

    local timestamp = items.add_child(activity, {
      marker = '*',
      body = util.timestamp()
    })

    return items.add_child(timestamp, child)
  else
    local timestamp = items.add_last_child(activity, {
      marker = '*',
      body = util.timestamp()
    }, lines)

    return items.add_child(timestamp, child)
  end
end

---@param item Item
---@param lines? string[]
function M.mark_start(item, lines)
  lines = lines or files.current_lines()
  items.set_item(item, { marker = '>' })

  return add_activity_timestamp(item, lines, {
    marker = '[',
    body = 'start'
  })
end

---@param item Item
---@param lines? string[]
function M.mark_done(item, lines)
  lines = lines or files.current_lines()
  items.set_item(item, { marker = '.' })

  add_activity_timestamp(item, lines, {
    marker = '[',
    body = 'done'
  })

  -- mark parent as done if there are no unfinished siblings
  -- and parent has activity
  local parent = items.parent(item, lines)
  if parent == nil then return end

  local parent_activity =
      items.find_child(function(x)
        return x.marker == '*' and x.body == 'activity' and items.relative_depth(parent, x) == 1
      end, parent, lines)

  if parent_activity == nil then return end

  local unfinished_sibling = -- depth 1 children of parent
      items.find_child(function(child)
        return
            child.marker:match('[%-%=]')
            and items.relative_depth(parent, child) == 1
            and child.position.row ~= item.position.row
      end, parent, lines)

  if unfinished_sibling == nil then
    M.mark_done(parent, lines)
    -- marks recursively, could loop forever if parent somehow loops
  end
end

return M
