local items = require('note.items')
local util  = require('note.util')

local M = {}

function M.mark_start(item)
  local activity_item = items.add_child(item, {
    marker = '*',
    body = 'activity'
  })

  local timestamp_item = items.add_child(activity_item, {
    marker = '*',
    body = util.timestamp()
  })

  items.add_child(timestamp_item, {
    marker = '[',
    body = 'start'
  })
end

return M
