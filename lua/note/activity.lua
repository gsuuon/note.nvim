local items = require('note.items')
local util  = require('note.util')
local files = require('note.files')

local M = {}

local function add_log_event(lines, activity, marker, body)
  local last = items.get_last_child(activity, lines)

  if last == nil then
    local timestamp_item = items.add_child(activity, {
      marker = '*',
      body = util.timestamp()
    })

    items.add_child(timestamp_item, {
      marker = marker,
      body = body
    })
  else
    local timestamp = items.add_item({
      marker = '*',
      body = util.timestamp(),
      position = {
        row = last.position.row + 1,
        col = activity.position.col + vim.o.sw
      }
    })

    items.add_child(timestamp, {
      marker = marker,
      body = body
    })
  end
end

---@param item Item
function M.mark_start(item)
  local activity = items.add_child(item, {
    marker = '*',
    body = 'activity'
  })

  add_log_event(files.current_lines(), activity, '[', 'start')
end

---@param item Item
function M.mark_done(item)
  local lines = files.current_lines()

  for x in items.children(item, lines) do
    -- Find activity item
    -- TODO items.find_child
    if x.marker == '*' and x.body == 'activity' then
      local activity = x
      add_log_event(lines, activity, '[', 'stop')
    end
  end
end

return M
