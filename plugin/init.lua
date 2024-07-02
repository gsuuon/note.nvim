vim.filetype.add({
  extension = {
    note = 'note',
  },
  pattern = {
    ['(.*)/notes/.*'] = {
      function(path, bufnr, prefix)
        if not prefix:match('(.+)://') then -- ignore URI's
          return 'note'
        end
      end,
      { priority = -math.huge }
    }
  }
})

require('note.commands').create_global_commands()
