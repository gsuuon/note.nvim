local util = require('note.util')

local M = {}

function M.exists(path)
  return vim.fn.filereadable(vim.fn.expand(path)) == 1
end

function M.dir_exists(path)
    return vim.fn.isdirectory(path) ~= 0
end

function M.join_paths(paths)
  return vim.fs.normalize(vim.fn.simplify(table.concat(paths, '\\')))
end

--- List the files, directories or both in a directory
---@param directory string
---@param type? 'directory' | 'file'
local function list(directory, type)
  local results = {}

  for name, ty in vim.fs.dir(directory, {
    depth = 1
  }) do
    if type == nil or ty == type then
      table.insert(results, M.join_paths({directory, name}))
    end
  end

  return results
end

function M.parent(dir)
  return vim.fs.normalize(vim.fn.fnamemodify(dir, ':h'))
end

local function next_item_in_list(xs, x)
  local _, idx = util.find_value(function(y) return y == x end, xs)

  if idx < #xs then
    return xs[idx + 1]
  end
end

local function previous_item_in_list(xs, x)
  local _, idx = util.find_value(function(y) return y == x end, xs)

  if idx > 1 then
    return xs[idx - 1]
  end
end

local function sibling_file(file, dir, forward)
  local results = list(dir, 'file')

  if not M.exists(file) then -- No current file on disk
    if forward then
      return results[1]
    else
      return results[#results]
    end
  end

  if forward then
    return next_item_in_list(results, file)
  else
    return previous_item_in_list(results, file)
  end
end

local function sibling_dir(dir, forward)
  local dirs = list(M.parent(dir), 'directory')

  if forward then
    return next_item_in_list(dirs, dir)
  else
    return previous_item_in_list(dirs, dir)
  end
end

function M.current_working_directory()
  return vim.fs.normalize(vim.fn.getcwd())
end

function M.current_file_directory()
  return vim.fs.normalize(vim.fn.expand('%:p:h'))
end

function M.current_file()
  return vim.fs.normalize(vim.fn.expand('%:p'))
end

function M.current_lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

---Tries to get the line at row of buffer
---@param row number 0-indexed row
---@param bufnr? number
---@return string
function M.line(row, bufnr)
  local success, lines = pcall(
    vim.api.nvim_buf_get_lines,
    bufnr or 0,
    row,
    row + 1,
    true
  )

  if success and #lines > 0 then
    return lines[1]
  end
end

---Tries to set the line at row of buffer
---@param row number 0-indexed row
---@param line string
---@param bufnr? number
function M.set_line(row, line, bufnr)
  return pcall(
    vim.api.nvim_buf_set_lines,
    bufnr or 0,
    row,
    row + 1,
    true,
    { line }
  )
end


--- Gets the next sibling in same directory or next directory
function M.sibling_across_dirs(file, forward)
  local dir = M.parent(file)

  local sibling_file_same_directory = sibling_file(file, dir, forward)

  if sibling_file_same_directory ~= nil then
    return sibling_file_same_directory
  end

  local sibling_directory = sibling_dir(dir, forward)

  if sibling_directory == nil then return end

  local sibling_dir_files = list(sibling_directory, 'file')

  if forward then
    return sibling_dir_files[1]
  else
    return sibling_dir_files[#sibling_dir_files]
  end
end

--- Find the longest item in directories which contains directory
function M.find_containing_directory(directory, directories)
  local function sort_longest(xs)
    local items = util.tbl_slice(xs, 0, #xs)

    table.sort(items, function(a,b)
      return #a > #b
    end)

    return items
  end

  return util.find_value(
    function (path)
      return util.starts_with(directory, vim.fs.normalize(path))
    end,
    sort_longest(directories)
  )
end

return M
