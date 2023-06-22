local item = require('note.item')

local function collect(text)
  local xs = {}

  item.find_item(function(x)
    table.insert(xs, x)
  end, vim.fn.split(text, '\n'))

  return xs
end

local text = [[
- beep
 . boop
  [ boop
## boop
]]


local expected = { {
    body = "beep",
    marker = "-",
    position = {
      col = 0,
      row = 0
    }
  }, {
    body = "boop",
    marker = ".",
    position = {
      col = 1,
      row = 1
    }
  }, {
    body = "boop",
    marker = "[",
    position = {
      col = 2,
      row = 2
    }
  }, {
    body = "boop",
    marker = "##",
    position = {
      col = 0,
      row = 3
    }
  } }

assert(vim.deep_equal(collect(text), expected))
-- vim.keymap.set('n', '<leader>,t', item.follow_link_at_cursor)
