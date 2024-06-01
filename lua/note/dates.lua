local files = require('note.files')
local util = require('note.util')

local function sort_numberlike(a, b)
  return tonumber(a) < tonumber(b)
end

local function ls(path, type, join)
  join = (join == nil) and false or join

  local results = {}

  for name, ty in vim.fs.dir(path, { depth = 1 }) do
    if ty == type then
      table.insert(results, join and files.join_paths({path, name}) or name)
    end
  end

  return results
end

---@param path string ls path
---@param type 'file' | 'directory'
local function ls_sorted_numberlike(path, type)
  local ls_numlike_paths = vim.tbl_filter(
    function(x)
      return tonumber(x) ~= nil
    end,
    ls(path, type)
  )

  table.sort(ls_numlike_paths, sort_numberlike)

  return ls_numlike_paths
end

local function index_of_closest_numberlike(y, xs)
  for i,x in ipairs(xs) do
    if tonumber(y) < tonumber(x) then return i end
  end

  return #xs
end

local function iter_date(start_item, paths, type, delta, skip_first)
  local xs = ls_sorted_numberlike(files.join_paths(paths), type)

  local idx do
    if start_item == nil then
      -- if start_item is nil then we're not trying to start in the middle of the list
      if delta == 1 then
        idx = 1
      else
        idx = #xs
      end
    else
      idx = util.index_of(start_item, xs)

      if idx == nil then
        idx = index_of_closest_numberlike(start_item, xs)
      end

      if skip_first then
        idx = idx + delta
      end
    end
  end

  return function()
    local idx_ = idx
    idx = idx + delta
    local res = xs[idx_]

    return res
  end
end

---This turns out to be pretty complicated, mostly because of handling the possibility of empty month or year folders
---The iterator, except for the first run, ensures we're only working with existing files/directories
---@param start_path string file path ending in /YYYY/MM/DD
---@return string result_path traversal result
local function traverse_daily_notes(start_path, forward)
  local path = vim.fs.normalize(start_path)

  local root, start_year, start_month, start_day = path:match('(.*)(%d%d%d%d)/(.+)/(.+)$')

  if root == nil or start_year == nil or start_month == nil or start_day == nil then
    error('Malformed start path for daily note file traversal: ' .. start_path)
  end

  -- invalidate these start portions if their parent path doesn't exist
  if not files.dir_exists(files.join_paths({root, start_year})) then
    start_month = nil
    start_day = nil
  elseif not files.dir_exists(files.join_paths({root, start_year, start_month})) then
    start_day = nil
  end

  local delta = forward and 1 or -1
  local skip_first = true

  for year in iter_date(start_year, {root}, 'directory', delta) do
    for month in iter_date(start_month, {root, year}, 'directory', delta) do
      for day in iter_date(start_day, {root, year, month}, 'file', delta, skip_first) do
        return files.join_paths({
          root,
          year,
          month,
          day
        })
      end
      skip_first = false
      start_day = nil
    end
    start_month = nil
  end
end

local function traverse(start_path, forward)
  local success, result = pcall(traverse_daily_notes, start_path, forward)
  if success then return result end
  error('Tried to find next/previous date but the start path does not exist: ' .. start_path .. '\nInner error: ' .. result)
end

return {
  traverse = traverse
}
