local M = {}

function M.find_value(match, map)
  for i, v in ipairs(map) do
    if match(v) then
      return v, i
    end
  end
end

function M.starts_with(str, start)
  return str:sub(1, #start) == start
end

function M.syntax_at(pos)
  return vim.tbl_map(
    function(id) return vim.fn.synIDattr(id, "name") end,
    vim.fn.synstack(pos.row + 1, pos.col + 1)
  )
end

function M.cursor()
  local pos = vim.api.nvim_win_get_cursor(0)
  -- this is, for some reason, 1-indexed rows and 0-indexed columns
  return {
    row = pos[1] - 1,
    col = pos[2]
  }
end

function M.cursor_set(pos)
  return vim.api.nvim_win_set_cursor(0, {pos.row + 1, pos.col})
end

function M.map_not_nil(x, fn, was_nil)
  if x ~= nil then
    return fn(x)
  else
    return was_nil()
  end
end

function M.map_list(xs, fn)
  local result = {}

  for k,v in pairs(xs) do
    result[k] = fn(v)
  end

  return result
end

function M.feedkeys(keys)
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes(keys, true, false, true),
    'nx',
    true
  )
end

function M.iter_keys(xs, fn)
  for k,_ in pairs(xs) do
    fn(k)
  end
end

return M
