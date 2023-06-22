if not vim.b.did_note_plugin then
  local note = require('note')
  local commands = require('note.commands')

  commands.create_buffer_commands()

  if note.config.keymap then
    commands.create_buffer_keymaps(note.config.keymap.prefix)
  end

  vim.wo.foldmethod = 'indent'

  vim.b.did_note_plugin = true
end

