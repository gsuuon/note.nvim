local items = require('note.items')

local test_lines = {
  'word',
  '- beep',
  ' . boop',
  '  [ boop',
  'not an item',
  '  - beep',
  '- boop',
  '## boop'
}

local expected_items =
  { {
      body = "beep",
      marker = "-",
      position = {
        col = 0,
        row = 1
      }
    }, {
      body = "boop",
      marker = ".",
      position = {
        col = 1,
        row = 2
      }
    }, {
      body = "boop",
      marker = "[",
      position = {
        col = 2,
        row = 3
      }
    }, {
      body = "beep",
      marker = "-",
      position = {
        col = 2,
        row = 5
      }
    }, {
      body = "boop",
      marker = "-",
      position = {
        col = 0,
        row = 6
      }
    }, {
      body = "boop",
      marker = "##",
      position = {
        col = 0,
        row = 7
      }
    } }

local function to_reg(x)
  vim.fn.setreg('x', vim.inspect(x))
end

local function test_item_parsing()
  local function collect(lines)
    local xs = {}

    items.find_item(function(x)
      table.insert(xs, x)
      return false
    end, lines)

    return xs
  end

  local result = collect(test_lines)

  assert(vim.deep_equal(result, expected_items))

  return result
end

local function test_scan_items()
  local result = items.scan_for_item({
    marker = '-',
    body = 'beep'
  }, 2, test_lines)

  local expected = {
    body = "beep",
    marker = "-",
    position = {
      col = 2,
      row = 5
    }
  }

  assert(vim.deep_equal(result, expected))

  return result
end

-- test_item_parsing()
test_scan_items()
