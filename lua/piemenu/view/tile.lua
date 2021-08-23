local CircleRange = require("piemenu.core.circle_range").CircleRange
local windowlib = require("piemenu.lib.window")
local stringlib = require("piemenu.lib.string")

local M = {}

local Tiles = {}
Tiles.__index = Tiles
M.Tiles = Tiles

local Tile = {}
Tile.__index = Tile
M.Tile = Tile

function Tiles.open(menus, position, start_angle, increment_angle)
  vim.validate({
    menus = {menus, "table"},
    position = {position, "table"},
    start_angle = {start_angle, "number", true},
    increment_angle = {increment_angle, "number", true},
  })
  start_angle = start_angle or menus.start_angle or 0
  increment_angle = increment_angle or menus.increment_angle or 45
  local radius = menus.radius or 12.0
  local width = menus.tile_width or 15
  local position_offset = menus.position_offset or {0, 0}

  vim.validate({
    increment_angle = {
      increment_angle,
      function(x)
        return x > 0
      end,
      "greater than 45",
    },
    radius = {
      radius,
      function(x)
        return x > 0
      end,
      "greater than 0",
    },
    tile_width = {
      width,
      function(x)
        return x > 0
      end,
      "greater than 0",
    },
    position_offset = {position_offset, "table"},
  })

  local tiles = {}
  local origin_pos = {position[1] + position_offset[1], position[2] + position_offset[2]}
  for angle = start_angle, start_angle + 359, increment_angle do
    local menu = menus[#tiles + 1]
    if not menu then
      break
    end

    local around_angle = increment_angle * 0.5
    local tile = Tile.open(angle, radius, width, origin_pos, menu, around_angle)
    if tile then
      table.insert(tiles, tile)
    end
  end

  local tbl = {_tiles = tiles}
  return setmetatable(tbl, Tiles)
end

function Tiles.activate(self, position)
  for _, tile in ipairs(self._tiles) do
    tile:deactivate()
  end
  local tile = self:find(position)
  if tile then
    tile:activate()
  end
end

function Tiles.find(self, position)
  for _, tile in ipairs(self._tiles) do
    if tile:include(position) then
      return tile
    end
  end
  return nil
end

function Tiles.close(self)
  for _, tile in ipairs(self._tiles) do
    tile:close()
  end
end

function Tile.open(angle, radius, width, origin_pos, menu, around_angle)
  vim.validate({
    angle = {angle, "number"},
    radius = {radius, "number"},
    width = {width, "number"},
    origin_pos = {origin_pos, "table"},
    menu = {menu, "table"},
  })
  if menu:is_empty() then
    return nil
  end

  local half_width = width / 2
  local height = 3
  local half_height = height / 2
  local max_col = vim.o.columns
  local max_row = vim.o.lines

  local rad = math.rad(angle)
  local origin_row, origin_col = unpack(origin_pos)
  local row = radius * math.sin(rad) + origin_row - half_height
  local col = radius * math.cos(rad) * 2 + origin_col - half_width -- *2 for row height and col width ratio
  if row <= 0 or col <= 0 or max_row <= row + height or max_col <= col + width then
    return nil
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, {stringlib.ellipsis(menu:to_string(), width - 2)})
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].modifiable = false

  local window_id = vim.api.nvim_open_win(bufnr, false, {
    width = width - 2, -- for border
    height = height - 2, -- for border
    anchor = "NW",
    relative = "editor",
    row = row + 1,
    col = col,
    external = false,
    focusable = false,
    style = "minimal",
    zindex = 51,
    border = {{" ", "PimenuNonCurrent"}},
  })
  vim.wo[window_id].winblend = 0

  local tbl = {
    _window_id = window_id,
    _menu = menu,
    _range = CircleRange.new(angle - around_angle, angle + around_angle),
    _origin_pos = origin_pos,
  }
  local self = setmetatable(tbl, Tile)
  self:deactivate()
  return self
end

function Tile.include(self, position)
  return self._range:include(self._origin_pos, position)
end

function Tile.close(self)
  windowlib.close(self._window_id)
end

function Tile.activate(self)
  vim.wo[self._window_id].winhighlight = "Normal:PimenuCurrent"
  vim.api.nvim_win_set_config(self._window_id, {border = {{" ", "PimenuCurrent"}}})
end

function Tile.deactivate(self)
  vim.wo[self._window_id].winhighlight = "Normal:PimenuNonCurrent"
  vim.api.nvim_win_set_config(self._window_id, {border = {{" ", "PimenuNonCurrent"}}})
end

function Tile.execute_action(self)
  return self._menu:execute_action()
end

vim.cmd("highlight default link PimenuCurrent Todo")
vim.cmd("highlight default link PimenuNonCurrent NormalFloat")

return M
