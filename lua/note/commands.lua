local note = require('note')
local util = require('note.util')
local files = require('note.files')
local items = require('note.items')

local M = {}

local function follow_link_at_cursor()
  local cursor = util.cursor()

  local link = items.get_link_at_col(
    vim.api.nvim_get_current_line(),
    cursor.col
  )

  if link == nil then return end

  local item = items.scan_for_item(link, cursor.row, files.current_lines())

  if item == nil then return end

  util.cursor_set(item.position, true)
end

local function goto_current_item()
  local item = items.find_item_matching(
    {
      marker = '>',
      body = '.'
    },
    files.current_lines()
  )

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
  local item = items.find_item_matching(
    {
      marker = args.fargs[1],
      body = args.fargs[2]
    },
    files.current_lines()
  )

  if item == nil then return end

  util.cursor_set(item.position, true)
end

local function mark_item(marker)
  local item = items.line_as_item(vim.api.nvim_get_current_line())

  if item ~= nil then
    vim.api.nvim_set_current_line(
      items.item_as_line(
        vim.tbl_extend('force', item, { marker = marker })
      )
    )
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
        '/.note/daily_template.note'
      })

      if files.exists(template_path) then
        local template = vim.fn.readfile(template_path)
        vim.api.nvim_put(template, 'l', false, false)
      end
    end
  end

  local function open_note_index()
    vim.cmd('e ' .. files.join_paths({current_note_root(), 'index'}))
  end

  vim.api.nvim_create_user_command('Note', open_note_day, {})
  vim.api.nvim_create_user_command('NoteIndex', open_note_index, {})
end

function M.create_buffer_commands(bufnr)
  bufnr = bufnr or 0

  vim.api.nvim_buf_create_user_command(
    bufnr,
    'NoteGoLink',
    follow_link_at_cursor,
    {}
  )

  vim.api.nvim_buf_create_user_command(
    bufnr,
    'NoteFindItem',
    goto_find_item,
    {nargs='+'}
  )

  vim.api.nvim_buf_create_user_command(
    bufnr,
    'NoteMarkItem',
    function(args) mark_item(args.fargs[1]) end,
    {nargs=1}
  )

  vim.api.nvim_buf_create_user_command(
    bufnr,
    'NoteCurrentItem',
    goto_current_item,
    {}
  )

  vim.api.nvim_buf_create_user_command(
    bufnr,
    'NoteNext',
    goto_next_note,
    {}
  )

  vim.api.nvim_buf_create_user_command(
    bufnr,
    'NotePrevious',
    goto_previous_note,
    {}
  )

  vim.api.nvim_buf_create_user_command(
    bufnr,
    'NoteTime',
    function(args)
      insert_timestamp(args.fargs[1] or '*', true)
    end,
    {nargs='?'}
  )

  vim.api.nvim_create_autocmd({"BufWritePre"}, {
    buffer = bufnr,
    callback = make_intermediate_directories
  })
end

function M.create_buffer_keymaps(prefix)
  local function bufkey(lhs, rhs, mode)
    mode = mode or 'n'
    vim.keymap.set(mode, prefix .. lhs, rhs, {buffer = true})
  end

  bufkey('n', ':NoteNext<cr>')
  bufkey('p', ':NotePrevious<cr>')
  bufkey('l', ':NoteGoLink<cr>')
  bufkey('t', ':NoteTime<cr>')

  -- [m]ark items
  for marker in ('.,>*=['):gmatch('.') do
    bufkey('m' .. marker, function() mark_item(marker) end)
  end
end

return M
