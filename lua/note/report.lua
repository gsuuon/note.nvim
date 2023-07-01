local items = require('note.items')

local M = {}

local function has_nonempty_line(lines)
  for _, line in ipairs(lines) do
    if #line > 0 then
      return true
    end
  end

  return false
end

local function get_item_type(item)
  if item.marker:match('[%[%*]') then
    return 'property'
  elseif item.marker:match('[%-%=%,%.]') then
    return 'task'
  elseif item.marker == '#' then
    return 'section'
  end
end

local task_status = {
  ['-'] = 'pending',
  [','] = 'cancelled',
  ['.'] = 'done',
  ['='] = 'paused',
}

function M.generate(lines)
  local report = {
    tasks = {
      done = {},
      paused = {},
      cancelled = {},
      pending = {}
    },
    sections = {}
  }

  local text_block = {}
  local current_section = {
    items = {},
  }

  for row1, line in ipairs(lines) do
    local item = items.parse_item(line, row1 - 1)
    if item == nil then
      table.insert(text_block, line)
    else
      if #text_block > 0 then
        if has_nonempty_line(text_block) then
          table.insert(current_section.items, {
            type = 'text',
            content = text_block
          })
        end

        text_block = {}
      end

      local type = get_item_type(item)

      table.insert(
        current_section.items,
        vim.tbl_extend('force', item, {type = type})
      )

      if type == 'task' then
        local status = task_status[item.marker]
        table.insert(report.tasks[status], item)
      end
    end
  end

  table.insert(report.sections, current_section)

  return report
end

return M
