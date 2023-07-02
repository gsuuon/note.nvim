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

local function insert_or_create(tbl, list_field, value)
  if type(tbl[list_field]) == 'table' then
    table.insert(tbl[list_field], value)
  else
    tbl[list_field] = { value }
  end
end

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

  local last_item

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
      item.type = type

      if type == 'task' then
        table.insert(current_section.items, item)

        local status = task_status[item.marker]
        table.insert(report.tasks[status], item)
      elseif type == 'property' then
        table.insert(current_section.items, item)
      elseif type == 'section' then
        if #current_section.items > 0 or current_section.title then
          table.insert(report.sections, current_section)
        end

        current_section = {
          title = item.body,
          depth = #item.marker,
          items = {}
        }
      end

      if last_item ~= nil
          and type ~= 'section'
          and items.relative_depth(last_item, item) == 1
      then
        insert_or_create(last_item, 'children', item)
        item.parent = last_item
      end
    end

    last_item = item
  end

  table.insert(report.sections, current_section)

  return report
end

return M
