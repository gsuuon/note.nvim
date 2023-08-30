if not vim.b.did_note_plugin then
  local note = require('note')
  local commands = require('note.commands')

  commands.create_buffer_commands()

  if note.config.keymap then
    commands.create_buffer_keymaps(note.config.keymap.prefix)
  end

  vim.wo.foldmethod = 'indent'

  local success, llm_prompts = pcall(require, 'llm.prompts.scopes')
  if success then
    llm_prompts.add_buffer_plugin_prompts(
      'note',
      require('note.llm.prompts')
    )
  end

  vim.b.did_note_plugin = true
end
