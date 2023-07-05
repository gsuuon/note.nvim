vim.filetype.add({
  extension = {
    note = 'note',
  },
  pattern = {
    ['.*/notes/.*'] = { 'note', { priority = -1 } }
  }
})

require('note.commands').create_global_commands()
