local util = require('note.util')

local M = {}

--- Checks if a file exists. False for directories.
function M.exists(path)
  return vim.fn.filereadable(vim.fn.expand(path)) == 1
end

--- Checks if a directory exists
function M.dir_exists(path)
  return vim.fn.isdirectory(path) ~= 0
end

---@param paths string[]
function M.join_paths(paths)
  return vim.fs.normalize(vim.fn.simplify(table.concat(paths, '\\')))
end

---@class ListOptions
---@field type? 'directory' | 'file'
---@field no_join? boolean don't join the file path with directory
---@field no_hidden? boolean filter out paths starting with '.'

--- List the files, directories or both in a directory
---@param directory string
---@param opts? ListOptions
function M.list(directory, opts)
  opts = opts or {}

  local results = {}

  for name, ty in vim.fs.dir(directory, {
    depth = 1
  }) do
    if opts.type == nil or ty == opts.type then
      if not (opts.no_hidden and util.starts_with(name, '.')) then
        if opts.no_join then
          table.insert(results, name)
        else
          table.insert(
            results,
            M.join_paths({ directory, name, })
          )
        end
      end
    end
  end

  return results
end

function M.parent(dir)
  return vim.fs.normalize(vim.fn.fnamemodify(dir, ':h'))
end

local function next_item_in_list(xs, x)
  local _, idx = util.find_value(function(y) return y == x end, xs)

  if idx == nil then return end

  if idx < #xs then
    return xs[idx + 1]
  end
end

local function previous_item_in_list(xs, x)
  local _, idx = util.find_value(function(y) return y == x end, xs)

  if idx == nil then return end

  if idx > 1 then
    return xs[idx - 1]
  end
end

---@param type 'file' | 'directory'
---@param path string
---@param forward boolean
---@return string | nil
local function sibling(type, path, forward)
  local parent = M.parent(path)
  local siblings = M.list(parent, { type = type })

  local exists
  if type == 'directory' then
    exists = M.dir_exists(path)
  else
    exists = M.exists(path)
  end

  if not exists then
    if forward then
      return siblings[1]
    else
      return siblings[#siblings]
    end
  end

  if forward then
    return next_item_in_list(siblings, path)
  else
    return previous_item_in_list(siblings, path)
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

function M.lines(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr or 0, 0, -1, false)
end

function M.commit_lines(commit, filepath, root)
  local proc = vim.system(
    { 'git', 'show', commit .. ':' .. filepath },
    {
      text = true,
      cwd = root
    }
  )

  return vim.fn.split(proc:wait().stdout, '\n')
end

-- TODO remove
function M.current_lines()
  return M.lines(0)
end

---Tries to get the line at row of buffer
---@param row number 0-indexed row
---@param bufnr? number
---@return string | nil
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
---@param insert? boolean
function M.set_line(row, line, bufnr, insert)
  local start = row
  local stop = start + (insert and 0 or 1)
  return pcall(
    vim.api.nvim_buf_set_lines,
    bufnr or 0,
    start,
    stop,
    true,
    { line }
  )
end

--- Gets the next sibling in same directory or next directory
function M.sibling_across_dirs(file, forward)
  local dir = M.parent(file)

  local sibling_file_same_directory = sibling('file', file, forward)

  if sibling_file_same_directory ~= nil then
    return sibling_file_same_directory
  end

  local sibling_directory = sibling('directory', dir, forward)

  if sibling_directory == nil then return end

  local sibling_dir_files = M.list(sibling_directory, { type = 'file' })

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

    table.sort(items, function(a, b)
      return #a > #b
    end)

    return items
  end

  return util.find_value(
    function(path)
      return util.starts_with(directory, vim.fs.normalize(path))
    end,
    sort_longest(directories)
  )
end

function M.current_commit(root)
  local proc = vim.system(
    { 'git', 'rev-parse', '--short=7', 'HEAD' },
    {
      text = true,
      cwd = root
    }
  )

  local out = proc:wait().stdout

  if out == nil or util.starts_with(out, 'fatal') then
    return nil, out
  end

  return (out:gsub('\n$', ''))
end

return M
