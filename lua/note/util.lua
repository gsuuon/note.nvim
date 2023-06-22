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

--- Takes a slice of a list of 0-indexed start and stop
function M.tbl_slice(tbl, start, stop, reverse)
  local res = {}
  local step = reverse and -1 or 1

  if not reverse then
    start = start + 1
  end

  for x=start, stop, step do
    table.insert(res, tbl[x])
  end

  return res
end

return M
