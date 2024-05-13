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

  vim.api.nvim_set_hl(0, '@note.cancelled.content', { link = "Conceal", default = true })
  vim.api.nvim_set_hl(0, '@note.done.content', { link = "SpecialComment", default = true })
  vim.api.nvim_set_hl(0, '@note.current.content', { link = "ModeMsg", default = true })
  vim.api.nvim_set_hl(0, '@note.label.content', { link = "Tag", default = true })
  vim.api.nvim_set_hl(0, '@note.cancelled.content', { link = "Conceal", default = true })
  vim.api.nvim_set_hl(0, '@note.info.content', { link = "Comment", default = true })

  vim.api.nvim_set_hl(0, '@note.pending.marker', { link = "Identifier", default = true })
  vim.api.nvim_set_hl(0, '@note.paused.marker', { link = "WarningMsg", default = true })
  vim.api.nvim_set_hl(0, '@note.cancelled.marker', { link = "Error", default = true })
  vim.api.nvim_set_hl(0, '@note.done.marker', { link = "Constant", default = true })
  vim.api.nvim_set_hl(0, '@note.current.marker', { link = "QuickFixLine", default = true })
  vim.api.nvim_set_hl(0, '@note.label.marker', { link = "Tag", default = true })
  vim.api.nvim_set_hl(0, '@note.info.marker', { link = "Comment", default = true })

  vim.api.nvim_set_hl(0, '@markup.heading.1.note', { link = "@markup.heading.1.markdown", default = true })
  vim.api.nvim_set_hl(0, '@markup.heading.2.note', { link = "@markup.heading.2.markdown", default = true })
  vim.api.nvim_set_hl(0, '@markup.heading.3.note', { link = "@markup.heading.3.markdown", default = true })
  vim.api.nvim_set_hl(0, '@markup.heading.4.note', { link = "@markup.heading.4.markdown", default = true })

  local ok, parsers = pcall(require, "nvim-treesitter.parsers")
  if ok then
    if parsers.has_parser() then
      vim.opt_local.foldmethod = 'expr'
    else
      vim.opt_local.foldmethod = 'indent'
    end
  end

  vim.b.did_note_plugin = true
end
