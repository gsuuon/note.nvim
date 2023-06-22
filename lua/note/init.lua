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

function M.setup(config)
  if config ~= nil then
    M.config = vim.tbl_deep_extend('force', M.config, config)
  end
end

return M
