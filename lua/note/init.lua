local M = {
  config = {
    spaces = {
      -- Defaults to first item
      '~',
    },
    keymap = { -- set keymap to false to prevent keys being mapped
      prefix = '<leader>n'
    }
  }
}

local function setup_treesitter_info()
  local parser_config = require('nvim-treesitter.parsers').get_parser_configs()
  parser_config.note = {
    install_info = {
      url = '~/code/gsuuon/tree-sitter-note',
      files = { 'src/parser.c', 'src/scanner.c' },
      branch = 'main',
      generate_requires_npm = false,
      requires_generate_from_grammar = false,
    },
  }
end

function M.setup(config)
  if config ~= nil then
    M.config = vim.tbl_deep_extend('force', M.config, config)
  end

  pcall(setup_treesitter_info)
end

return M
