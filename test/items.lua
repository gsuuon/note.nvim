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

---Utility function to help set test expected values. Sets the register 'x' to a value
local function to_reg(x)
  vim.fn.setreg('x', vim.inspect(x))
end

local function collect(iter_fun)
  local results = {}

  for x in iter_fun do
    table.insert(results, x)
  end

  return results
end

local function test_item_parsing()
  local result = collect(items.items(test_lines))

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

local function test_children()
  local lines = {
    'a',
    '- b',
    ' * c',
    ' [ c1',
    '   * c2',
    '   feafe',
    '- d',
    'e'
  }

  local expected_children =
  { {
    body = "c",
    marker = "*",
    position = {
      col = 1,
      row = 2
    }
  }, {
    body = "c1",
    marker = "[",
    position = {
      col = 1,
      row = 3
    }
  }, {
    body = "c2",
    marker = "*",
    position = {
      col = 3,
      row = 4
    }
  } }

  local first_b = items.find_item_matching_iter({
    marker = '-',
    body = '.'
  }, table.pack(ipairs(lines)))


  local children = collect(items.children(first_b, lines))

  assert(vim.deep_equal(children, expected_children))
end

test_item_parsing()
test_scan_items()
test_children()

vim.notify('All tests passed')
