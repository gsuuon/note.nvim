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

return M
