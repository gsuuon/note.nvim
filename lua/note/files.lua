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

local scan = require'plenary.scandir' -- just using this to get directory contents, vim.fs.dir seems broken
-- TODO use vim.fs.dir instead
local function directories_in(dir)
  return vim.tbl_map(
    vim.fs.normalize,
    scan.scan_dir(dir, { only_dirs = true, depth = 1 })
  )
end

local function files_in(dir)
  return vim.tbl_map(
    vim.fs.normalize,
    scan.scan_dir(dir, { hidden = true, depth = 1 })
  )
end

function M.parent(dir)
  return vim.fs.normalize(vim.fn.fnamemodify(dir, ':h'))
end

local function next_item_in_list(xs, x)
  local _, idx = util.find_value(function(y) return y == x end, xs)

  if idx + 1 < #xs then
    return xs[idx + 1]
  end
end

local function previous_item_in_list(xs, x)
  local _, idx = util.find_value(function(y) return y == x end, xs)

  if idx - 1 > 0 then
    return xs[idx - 1]
  end
end

local function sibling_file(file, dir, forward)
  local results = files_in(dir)

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
  local dirs = directories_in(M.parent(dir))

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

function M.current_lines(start, stop)
  start = start or 0
  stop = stop or -1
  return vim.api.nvim_buf_get_lines(0, start, stop, false)
end

--- Gets the next sibling in same directory or next directory
function M.sibling_across_dirs(file, forward)
  local dir = M.parent(file)

  local sibling_file_same_directory = sibling_file(file, dir, forward)

  if sibling_file_same_directory ~= nil then
    return sibling_file_same_directory
  end

  local sibling_dir_files = files_in(sibling_dir(dir, forward))

  if forward then
    return sibling_dir_files[1]
  else
    return sibling_dir_files[#sibling_dir_files]
  end
end

--- Find which of directories contains directory, if any
function M.find_containing_directory(directory, directories)
  return util.find_value(
    function (path)
      return util.starts_with(directory, vim.fs.normalize(path))
    end,
    directories
  )
end

return M
