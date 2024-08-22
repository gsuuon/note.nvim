local note = require('note')
local util = require('note.util')
local files = require('note.files')
local dates = require('note.dates')
local items = require('note.items')
local activity = require('note.activity')
local report = require('note.report')
local ref = require('note.ref')

local M = {}

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

---@return string | nil
local function path_relative_to_root(path)
  local resolved = vim.fn.resolve(path)
  local root = vim.fn.resolve(current_note_root())

  if util.starts_with(resolved, root) then
    return resolved:sub(#root + 1)
  end
end

---@param target Target
local function find_item(target)
  return items.scan_for_item(
    target,
    util.cursor().row,
    files.current_lines()
  )
end

local function link_filepath(link)
  if util.starts_with(link.file.path, '/') then
    return files.join_paths({
      current_note_root(),
      link.file.path
    })
  end

  return files.join_paths({
    files.current_file_directory(),
    link.file.path
  })
end

local function follow_link_at_cursor()
  local cursor = util.cursor()

  local link = items.get_link_at_col(
    vim.api.nvim_get_current_line(),
    cursor.col
  )

  if link == nil then return end

  if link.file ~= nil then
    local filepath = link_filepath(link)

    if link.file.commit and link.file.commit ~= '' then
      filepath = path_relative_to_root(filepath):gsub('^/', '')

      local lines = files.commit_lines(
        link.file.commit,
        filepath,
        current_note_root()
      )
      -- TODO check if commit_lines failed

      local bufname = filepath .. '@' .. link.file.commit
      local bufnr = vim.fn.bufnr(bufname, true)

      vim.api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
      vim.api.nvim_set_option_value('filetype', 'note', { buf = bufnr })
      vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, lines)

      vim.cmd.b(bufnr)
    else
      vim.cmd.edit(filepath)
    end
  end

  local lines = files.current_lines()

  -- TODO if ref can make case sensitive and add case sensitive refs
  local item = items.scan_for_item(
    link.link_target,
    (link.file == nil) and cursor.row or 0,
    lines,
    false
  )

  if item == nil then return end

  if link.link_target.action == 'parent' then
    item = items.parent(item, lines) or item
  end

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
  local file = dates.traverse(files.current_file(), forward)

  if file ~= nil then
    vim.cmd.edit(file)
  end
end

local function goto_next_note() goto_note(true) end
local function goto_previous_note() goto_note(false) end

local function goto_find_item(args)
  local item = find_item({
    marker = args.fargs[1],
    body = args.fargs[2] or '.'
  })

  if item == nil then return end

  util.cursor_set(item.position, true)
end

---@param marker string
---@param row1? number 1-indexed row number
local function mark_item(marker, row1)
  local row = row1 and row1 - 1 or util.cursor().row

  local line = files.line(row)
  if line == nil then return end

  local item = items.parse_item(line, row)

  if item == nil then return end
  items.set_item(item, { marker = marker })
end

---Mark item and all children with matching markers
local function mark_item_children(marker)
  local parent = items.cursor_item()
  if parent == nil then return end

  items.set_item(parent, { marker = marker })

  for child in items.children(parent, files.current_lines()) do
    if child.marker == parent.marker then
      items.set_item(child, { marker = marker })
    end
  end
end

local function add_child(args)
  if #args.fargs ~= 2 then
    error('Missing marker or body argument')
  end

  local parent = items.cursor_item()

  if parent == nil then return end

  items.add_child(parent, {
    marker = args.fargs[1],
    body = args.fargs[2]
  })
end

local function make_intermediate_directories(ctx)
  vim.fn.mkdir(files.parent(ctx.file), 'p')
end

local function insert_timestamp(marker, pre_indent_child)
  local lines = { (marker or '*') .. ' ' .. util.timestamp() }

  if pre_indent_child then
    table.insert(lines, '  ')
  else
    table.insert(lines, '')
  end

  local pos = util.cursor()

  vim.api.nvim_put(lines, "l", true, false)
  -- nvim_put's follow behavior seems to be pretty complicated
  -- manually setting the position is the only way to be consistent

  util.cursor_set({
    col = pos.col,
    row = pos.row + 2
  })

  vim.cmd.startinsert({ bang = true })
end

local function is_day_note(path)
  return vim.fs.normalize(path):match('%d%d%d%d/%d%d/%d%d') ~= nil
end

local function open_note_day()
  local notes_root = current_note_root()

  local path_note_today = files.join_paths({
    notes_root,
    os.date("%Y/%m/%d")
  })

  vim.cmd('e ' .. path_note_today)

  local lines = files.current_lines()

  if #lines == 1 and lines[1] == '' then
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

local function link_item_today(args)
  if args.fargs[1] == nil then 
    vim.notify('Expected arguments: marker [body]', vim.log.levels.ERROR)
  end

  local relative_path = path_relative_to_root(files.current_file())

  local cursor_item = items.cursor_item()
  if cursor_item == nil then return end

  ref.yank_item(cursor_item, relative_path)

  open_note_day()

  local target = {
    marker = args.fargs[1],
    body = args.fargs[2] or '.'
  }

  local lines = files.current_lines()
  local target_item = items.scan_for_item(target, 0, lines, false, true)

  if target_item == nil then
    -- TODO just copy to end of file
    vim.notify(vim.inspect(target), vim.log.levels.ERROR, { title = 'Item not found' })
  else
    ref.paste_item(
      target_item,
      path_relative_to_root(files.current_file()),
      current_note_root()
    )
  end
end

function M.create_global_commands()
  --- Gets the space based on current file, then cwd, else first item in config.spaces

  local function open_note_index()
    vim.cmd('e ' .. files.join_paths({ current_note_root(), 'index' }))
  end

  local function open(args)
    if #args.fargs > 0 then
      -- join fargs with note root
      local file = files.join_paths(
        vim.iter({
          current_note_root(),
          args.fargs,
        }):flatten():totable()
      )

      vim.cmd.edit(file)
    else
      open_note_day()
    end
  end

  local function complete_open(cur, line, col)
    -- TODO use cur / col in case we arrow back to a previous path
    local arg_paths = vim.fn.split(line, ' ')

    local function list_files(paths)
      return vim.tbl_map(
        function(x)
          return x:gsub(' ', '\\ ') -- Escape the space
        end,
        files.list(
          files.join_paths(paths),
          {
            no_join = true,
            no_hidden = true
          }
        )
      )
    end

    if cur == '' then
      -- last path is complete
      local paths = util.tbl_slice(arg_paths, 1, #arg_paths)
      table.insert(paths, 1, current_note_root())
      return list_files(paths)
    end

    -- last path is being typed
    local paths = util.tbl_slice(arg_paths, 1, #arg_paths - 1)
    table.insert(paths, 1, current_note_root())

    local head_files = list_files(paths)

    if cur == '' then return head_files end

    return vim.fn.matchfuzzy(head_files, cur)
  end

  vim.api.nvim_create_user_command(
    'Note',
    open,
    {
      nargs = '*',
      complete = complete_open,
    }
  )

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
    {
      nargs = '+',
      complete = function(cur_arg, arg_line)
        if arg_line:find('^NoteFindItem $') then
          return { 't', 'p', 's', '-', '.', ',', '=', '[', '*' }
        end

        local marker = arg_line:match('^NoteFindItem (.) ')
        if marker ~= 's' then
          -- TODO use report to autocomplete any item type
          return
        end

        local lines = files.current_lines()

        local sections = {}
        for _, line in ipairs(lines) do
          local _, title = line:match('^(#+) (.+)$')
          if title ~= nil then
            table.insert(sections, title)
          end
        end

        if cur_arg == '' then return sections end

        return vim.fn.matchfuzzy(sections, cur_arg)
      end
    }
  )

  vim.api.nvim_buf_create_user_command(
    0,
    'NoteMarkItem',
    function(args)
      if args.range == 2 then
        for row = args.line1, args.line2 do
          mark_item(args.fargs[1], row)
        end
      else
        mark_item(args.fargs[1])
      end
    end,
    {
      nargs = 1,
      range = true
    }
  )

  vim.api.nvim_buf_create_user_command(
    0,
    'NoteMarkItemChildren',
    function(args)
      mark_item_children(args.fargs[1])
    end,
    { nargs = 1 }
  )

  vim.api.nvim_buf_create_user_command(
    0,
    'NoteCurrentItem',
    goto_current_item,
    {}
  )

  vim.api.nvim_buf_create_user_command(
    0,
    'NoteAddChild',
    add_child,
    {
      nargs = '+',
    }
  )

  vim.api.nvim_buf_create_user_command(
    0,
    'NoteTaskStart',
    function()
      local cursor_item = items.cursor_item()
      if cursor_item == nil then return end

      activity.mark_start(cursor_item)
    end,
    {}
  )

  vim.api.nvim_buf_create_user_command(
    0,
    'NoteTaskDone',
    function()
      local cursor_item = items.cursor_item()
      if cursor_item == nil then return end

      activity.mark_done(cursor_item, files.current_lines())
    end,
    {}
  )

  vim.api.nvim_buf_create_user_command(
    0,
    'NoteReport',
    function()
      local data = report.generate(files.current_lines())

      local tasks = {}

      for status, status_tasks in pairs(data.tasks) do
        table.insert(tasks, status .. ': ' .. #status_tasks)
      end

      local sections = {}

      for _, section in ipairs(data.sections) do
        table.insert(
          sections,
          table.concat(section.scope or { '<top>' }, '/')
          .. ': ' .. #section.items .. ' item(s)'
        )
      end

      vim.notify(table.concat(tasks, '\n'), nil, { title = 'tasks' })
      vim.notify(table.concat(sections, '\n'), nil, { title = 'sections' })
    end,
    {}
  )

  vim.api.nvim_buf_create_user_command(
    0,
    'NoteRefCreate',
    function()
      local relative_path = path_relative_to_root(files.current_file())
      local item = items.cursor_item()
      if item == nil then return end
      ref.create_ref_info_item(item, relative_path)
    end,
    {}
  )

  vim.api.nvim_buf_create_user_command(
    0,
    'NoteRefYank',
    function()
      local relative_path = path_relative_to_root(files.current_file())
      local item = items.cursor_item()
      if item == nil then return end
      ref.yank_ref(item, relative_path)
    end,
    {}
  )

  vim.api.nvim_buf_create_user_command(
    0,
    'NoteRefPaste',
    function() ref.insert_ref() end,
    {}
  )

  vim.api.nvim_buf_create_user_command(
    0,
    'NoteItemLinkedYank',
    function()
      local relative_path = path_relative_to_root(files.current_file())

      local item = items.cursor_item()
      if item == nil then return end

      ref.yank_item(item, relative_path)
    end,
    {}
  )

  vim.api.nvim_buf_create_user_command(
    0,
    'NoteItemLinkedPaste',
    function()
      ref.paste_item(
        items.cursor_item(),
        path_relative_to_root(files.current_file()),
        current_note_root()
      )
    end,
    {}
  )

  vim.api.nvim_buf_create_user_command(
    0,
    'NoteItemLinkToday',
    link_item_today,
    { nargs = '+' }
  )

  vim.api.nvim_buf_create_user_command(
    0,
    'NoteLinkPinCommit',
    function()
      local pos = util.cursor()
      local link = items.get_link_at_col(
        vim.api.nvim_get_current_line(),
        pos.col
      )

      if link == nil then return end

      local update_link_file
      if link.file == nil or link.file.path == nil then
        update_link_file = {
          path = path_relative_to_root(files.current_file()),
        }
      else
        update_link_file = {
          path = link.file.path
        }
      end

      local current_commit, err = files.current_commit(current_note_root())
      if current_commit == nil then
        vim.notify(
          err or '',
          vim.log.levels.ERROR,
          { title = 'git error' }
        )
        return
      end

      update_link_file.commit = current_commit

      local link_str = items.link_to_str(vim.tbl_extend(
        'force',
        link,
        { file = update_link_file }
      ))

      vim.api.nvim_buf_set_text(
        0,
        pos.row,
        link.start,
        pos.row,
        link.stop,
        { link_str }
      )
    end,
    {}
  )

  vim.api.nvim_buf_create_user_command(
    0,
    'NoteTime',
    function(args)
      insert_timestamp(
        args.fargs[1] or '*',
        not (note.config.pre_indent_time == false) -- defaults to true
      )
    end,
    { nargs = '?' }
  )

  vim.api.nvim_buf_create_user_command(
    0,
    'NoteConvertLinksSquareToCurly',
    util.convert_link_square_to_curly,
    {}
  )

  vim.api.nvim_create_autocmd({ "BufWritePre" }, {
    buffer = 0,
    callback = make_intermediate_directories
  })

end

function M.create_buffer_keymaps(prefix)
  local function bufkey(lhs, rhs, mode)
    mode = mode or 'n'
    vim.keymap.set(mode, prefix .. lhs, rhs, { buffer = true })
  end

  if is_day_note(vim.fn.bufname()) then
    bufkey('n', ':NoteNext<cr>')
    bufkey('p', ':NotePrevious<cr>')
  end

  bufkey('l', ':NoteGoLink<cr>')
  bufkey('t', ':NoteTime<cr>')
  bufkey('s', ':NoteTaskStart<cr>')
  bufkey('d', ':NoteTaskDone<cr>')
  bufkey('c', ':NoteCurrentItem<cr>')

  local function dot_repeatable(fn)
    -- https://gist.github.com/kylechui/a5c1258cd2d86755f97b10fc921315c3
    return function()
      _G.note_last_op = fn
      vim.o.operatorfunc = 'v:lua.note_last_op'
      return 'g@l'
    end
  end

  for marker in ('-.,>*=['):gmatch('.') do
    -- [m]ark items
    vim.keymap.set(
      'n',
      prefix .. 'm' .. marker,
      dot_repeatable(function()
        mark_item(marker)
      end),
      { buffer = true, expr = true }
    )

    -- [m]ark items (visual)
    vim.keymap.set(
      'v',
      prefix .. 'm' .. marker,
      ":'<,'>NoteMarkItem " .. marker .. '<cr>'
    )

    -- [M]ark item children
    vim.keymap.set(
      'n',
      prefix .. 'M' .. marker,
      dot_repeatable(function()
        mark_item_children(marker)
      end),
      { buffer = true, expr = true }
    )

    -- [f]ind item
    vim.keymap.set(
      'n',
      prefix .. 'f' .. marker,
      dot_repeatable(function()
        local item = find_item({ marker = marker, body = '.' })
        if item == nil then return end

        util.cursor_set(item.position, true)
      end),
      { buffer = true, expr = true }
    )
  end
end

M.current_space = current_space
M.current_note_root = current_note_root

-- show(vim.fn.matchfuzzy({'Foo','Bar'}, 'f'))

return M
