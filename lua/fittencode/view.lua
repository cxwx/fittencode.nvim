local api = vim.api
local fn = vim.fn

local Base = require('fittencode.base')
local Color = require('fittencode.color')

local M = {}

---@type integer
local namespace = nil

---@class VirtLine
---@field text string @The text of the virtual line
---@field hl string @The highlight group of the virtual line

---@alias VirtText VirtLine[] @The virtual text to be displayed

-- Generate virtual text for suggestions
---@param suggestions Suggestions @The suggestions to be displayed
---@return VirtText|nil @The virtual text to be displayed
local function generate_virt_text(suggestions)
  if suggestions == nil then
    return
  end
  ---@type VirtText
  local virt_text = {}
  for _, line in ipairs(suggestions) do
    table.insert(virt_text, { { line, Color.FittenSuggestion } })
  end
  return virt_text
end

-- Draw virtual text on buffer
---@param virt_text VirtText @The virtual text to be displayed
local function draw_virt_text(virt_text)
  if virt_text == nil or vim.tbl_count(virt_text) == 0 then
    return
  end

  local row, col = Base.get_cursor()

  api.nvim_buf_set_extmark(0, namespace, row, col, {
    virt_text = virt_text[1],
    virt_text_pos = 'inline',
    hl_mode = 'combine',
  })

  table.remove(virt_text, 1)

  if vim.tbl_count(virt_text) > 0 then
    api.nvim_buf_set_extmark(0, namespace, row, 0, {
      virt_lines = virt_text,
    })
  end
end

-- Clear virtual text on buffer
---@param ns integer|nil
---@param bufnr integer|nil
local function clear_ns(ns, bufnr)
  if ns ~= nil and bufnr ~= nil then
    api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  end
end

-- Reset the namespace for virtual text
local function reset_ns()
  if namespace ~= nil then
    clear_ns(namespace, 0)
  else
    namespace = api.nvim_create_namespace('Fittencode')
  end
end

-- Clear virtual text on buffer
function M.clear_virt_text()
  clear_ns(namespace, 0)
end

-- Move the cursor to the center of the window
---@param virt_height integer @The height of the virtual text
local function move_to_center_vertical(virt_height)
  local row, _ = Base.get_cursor()
  local relative_row = row - fn.line('w0')
  local height = api.nvim_win_get_height(0)
  local center = math.ceil(height / 2)
  height = height - vim.o.scrolloff
  if relative_row + virt_height > height and math.abs(relative_row + 1 - center) > 2 and row > center then
    Base.feedkeys('<Esc>zza')
  end
end

-- Render virtual text on buffer
---@param suggestions Suggestions @The suggestions to be displayed
function M.render_virt_text(suggestions)
  local virt_text = generate_virt_text(suggestions)
  if virt_text == nil then
    return
  end
  reset_ns()
  move_to_center_vertical(vim.tbl_count(virt_text))
  draw_virt_text(virt_text)
end

local autoindent = nil
local smartindent = nil
local formatoptions = nil
local textwidth = nil

-- Disable autoindent, smartindent, formatoptions, textwidth for local formatting
local function local_fmt_clear()
  autoindent = vim.bo.autoindent
  smartindent = vim.bo.smartindent
  formatoptions = vim.bo.formatoptions
  textwidth = vim.bo.textwidth
  vim.bo.autoindent = false
  vim.bo.smartindent = false
  vim.bo.formatoptions = ''
  vim.bo.textwidth = 0
end

-- Recovery autoindent, smartindent, formatoptions, textwidth for local formatting
local function local_fmt_recovery()
  vim.bo.autoindent = autoindent
  vim.bo.smartindent = smartindent
  vim.bo.formatoptions = formatoptions
  vim.bo.textwidth = textwidth
end

-- Silence LSP
local function silence_lsp()
  Base.feedkeys('<Esc>a')
end

-- Move the cursor to the end of the text
---@param row integer @The row of the cursor
---@param col integer @The column of the cursor
---@param count integer @The count of the lines
---@param lines string[] @The lines have been appended
local function move_cursor_to_text_end(row, col, count, lines)
  if count == 1 then
    local first_len = string.len(lines[1])
    if first_len ~= 0 then
      api.nvim_win_set_cursor(0, { row + 1, col + first_len })
    end
  else
    local last_len = string.len(lines[count])
    api.nvim_win_set_cursor(0, { row + count, last_len })
  end
end

-- Append text at position
---@param row integer @The row of the cursor
---@param col integer @The column of the cursor
---@param count integer @The count of the lines
---@param lines string[] @The lines to be appended
local function append_text_at_pos(row, col, count, lines)
  for i = 1, count, 1 do
    local line = lines[i]
    local len = string.len(line)
    if i == 1 then
      if len ~= 0 then
        api.nvim_buf_set_text(0, row, col, row, col, { line })
      end
    else
      local max = api.nvim_buf_line_count(0)
      local try_row = row + i - 1
      if try_row >= max then
        api.nvim_buf_set_lines(0, max, max, false, { line })
      else
        if string.len(api.nvim_buf_get_lines(0, try_row, try_row + 1, false)[1]) ~= 0 then
          api.nvim_buf_set_lines(0, try_row, try_row, false, { line })
        else
          api.nvim_buf_set_text(0, try_row, 0, try_row, 0, { line })
        end
      end
    end
  end
end

-- Undojoin
local function undojoin()
  Base.feedkeys('<C-g>u')
end

-- Set text to buffer
---@param lines string[] @The lines to be set to buffer
function M.set_text(lines)
  local_fmt_clear()

  local row, col = Base.get_cursor()
  local count = vim.tbl_count(lines)

  undojoin()
  -- CursorMovedI CursorHoldI
  append_text_at_pos(row, col, count, lines)
  move_cursor_to_text_end(row, col, count, lines)
  -- InsertLeave CursorMoved
  silence_lsp()
  api.nvim_command('redraw!')

  local_fmt_recovery()
end

-- Feed tab key
function M.feed_tab()
  Base.feedkeys('<Tab>')
end

return M
