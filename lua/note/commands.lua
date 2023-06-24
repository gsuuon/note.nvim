local note = require('note')
local util = require('note.util')
local files = require('note.files')
local items = require('note.items')

local M = {}

local function find_item(target)
  return items.find_item_matching_iter(
    target,
    util.iter(files.current_lines())
  )
end

local function follow_link_at_cursor()
  local cursor = util.cursor()

  local link = items.get_link_at_col(
    vim.api.nvim_get_current_line(),
    cursor.col
  )

  if link == nil then return end

  if link.file ~= nil then
    local filepath = files.join_paths({
      files.current_file_directory(),
      link.file,
    })
    vim.cmd.edit(filepath)
  end

  link.body = util.pattern_to_case_insensitive(link.body)

  local item = items.scan_for_item(
    link,
    cursor.row,
    files.current_lines()
  )

  if item == nil then return end

  util.cursor_set(item.position, link.file == nil)
end

local function goto_current_item()
  local item = find_item({
    marker = '>',
    body = '.'
  })

  if item == nil then return end

  util.cursor_set(item.position, true)
end

local function goto_note(forward)
  local file = files.sibling_across_dirs(files.current_file(), forward)

  if file ~= nil then
    vim.cmd.edit(file)
  end
end

local function goto_next_note() goto_note(true) end
local function goto_previous_note() goto_note(false) end

local function goto_find_item(args)
  local item = find_item({
    marker = args.fargs[1],
    body = args.fargs[2]
  })

  if item == nil then return end

  util.cursor_set(item.position, true)
end

---@param marker string
---@param row? number 1-indexed row number
local function mark_item(marker, row)
  row = row or util.cursor().row

  local line = files.line(row)
  local item = items.line_as_item(line)

  if item ~= nil then
    item.marker = marker

    files.set_line(row, items.item_as_line(item))
  end
end

---Mark item and all children with matching markers
local function mark_item_children(marker)
  local row = util.cursor().row

  local parent = items.line_as_item(files.line(row))

  if parent ~= nil then
    files.set_line(
      row,
      items.item_as_line(
        vim.tbl_extend('force',
          parent,
          {
            marker = marker
          }
        )
      )
    )

    parent.position = {
      col = parent.col,
      row = row
    }

    for child in items.children(parent, files.current_lines()) do
      if child.marker == parent.marker then
        child.marker = marker

        files.set_line(
          child.position.row,
          items.item_as_line(child)
        )
      end
    end
  end
end

local function make_intermediate_directories()
  local parent_dir = files.current_file_directory()
  if not files.dir_exists(parent_dir) then
    vim.fn.mkdir(parent_dir, 'p')
  end
end

local function insert_timestamp(marker, pre_indent_child)
  local lines = { vim.fn.strftime(marker .. ' %I:%M.%S %p') }

  if pre_indent_child then table.insert(lines, '  ') end

  local pos = util.cursor()

  vim.api.nvim_put(lines, "l", true, false)
    -- nvim_put's follow behavior seems to be pretty complicated
    -- manually setting the position is the only way to be consistent

  util.cursor_set({
    col = pos.col,
    row = pos.row + 2
  })

  vim.cmd.startinsert({bang = true})
end

local function is_day_note(path)
  return path:match('%d%d%d%d/%d%d/%d%d') ~= nil
end

function M.create_global_commands()
  --- Gets the space based on current file, then cwd, else first item in config.spaces
  local function current_space()
    local file_space = files.find_containing_directory(
      files.current_file_directory(),
      note.config.spaces
    )

    if file_space ~= nil then return file_space end

    local working_space = files.find_containing_directory(
      files.current_working_directory(),
      note.config.spaces
    )

    if working_space ~= nil then return working_space end

    return note.config.spaces[1]
  end

  local function current_note_root()
    return files.join_paths({
      current_space(),
      'notes/'
    })
  end

  local function open_note_day()
    local notes_root = current_note_root()

    local path_note_today = files.join_paths({
      notes_root,
      os.date("%Y/%m/%d")
    })

    vim.cmd('e ' .. path_note_today)

    if not files.exists(path_note_today) then
      local template_path = files.join_paths({
        notes_root,
        '/.note/daily_template'
      })

      if files.exists(template_path) then
        vim.api.nvim_put(
          vim.fn.readfile(template_path),
          'l',
          false,
          false
        )
      else
        vim.api.nvim_put({
          '# Goal',
          '',
          '# Tasks',
          '',
          '# Notes',
        }, 'l', false, false)
      end
    end
  end

  local function open_note_index()
    vim.cmd('e ' .. files.join_paths({current_note_root(), 'index'}))
  end

  vim.api.nvim_create_user_command('Note', open_note_day, {})
  vim.api.nvim_create_user_command('NoteIndex', open_note_index, {})
end

function M.create_buffer_commands()
  if is_day_note(vim.fn.bufname()) then
    vim.api.nvim_buf_create_user_command(
      0,
      'NoteNext',
      goto_next_note,
      {}
    )

    vim.api.nvim_buf_create_user_command(
      0,
      'NotePrevious',
      goto_previous_note,
      {}
    )
  end

  vim.api.nvim_buf_create_user_command(
    0,
    'NoteGoLink',
    follow_link_at_cursor,
    {}
  )

  vim.api.nvim_buf_create_user_command(
    0,
    'NoteFindItem',
    goto_find_item,
    {nargs='+'}
  )

  vim.api.nvim_buf_create_user_command(
    0,
    'NoteMarkItem',
    function(args)
      if args.range == 2 then
        for row=args.line1,args.line2 do
          mark_item(args.fargs[1], row - 1)
        end
      else
        mark_item(args.fargs[1])
      end
    end,
    {
      nargs=1,
      range=true
    }
  )

  vim.api.nvim_buf_create_user_command(
    0,
    'NoteMarkItemChildren',
    function(args)
      mark_item_children(args.fargs[1])
    end,
    {nargs=1}
  )

  vim.api.nvim_buf_create_user_command(
    0,
    'NoteCurrentItem',
    goto_current_item,
    {}
  )

  vim.api.nvim_buf_create_user_command(
    0,
    'NoteTime',
    function(args)
      insert_timestamp(args.fargs[1] or '*', true)
    end,
    {nargs='?'}
  )

  vim.api.nvim_create_autocmd({"BufWritePre"}, {
    buffer = 0,
    callback = make_intermediate_directories
  })
end

function M.create_buffer_keymaps(prefix)
  local function bufkey(lhs, rhs, mode)
    mode = mode or 'n'
    vim.keymap.set(mode, prefix .. lhs, rhs, {buffer = true})
  end

  if is_day_note(vim.fn.bufname()) then
    bufkey('n', ':NoteNext<cr>')
    bufkey('p', ':NotePrevious<cr>')
  end

  bufkey('l', ':NoteGoLink<cr>')
  bufkey('t', ':NoteTime<cr>')

  local function dot_repeatable(fn)
    -- https://gist.github.com/kylechui/a5c1258cd2d86755f97b10fc921315c3
    return function ()
      _G.note_last_op = fn
      vim.o.operatorfunc = 'v:lua.note_last_op'
      return 'g@l'
    end
  end

  -- [m]ark items
  for marker in ('-.,>*=['):gmatch('.') do
    vim.keymap.set(
      'n',
      prefix .. 'm' .. marker,
      dot_repeatable(function()
        mark_item(marker)
      end),
      { buffer = true, expr = true }
    )

    vim.keymap.set(
      'n',
      prefix .. 'M' .. marker,
      dot_repeatable(function()
        mark_item_children(marker)
      end),
      { buffer = true, expr = true }
    )

    vim.keymap.set(
      'v',
      prefix .. 'm' .. marker,
      ":'<,'>NoteMarkItem " .. marker .. '<cr>'
    )
  end
end

return M
