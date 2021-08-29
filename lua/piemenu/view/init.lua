local Menus = require("piemenu.core.menu").Menus
local Background = require("piemenu.view.background").Background
local Tiles = require("piemenu.view.tile").Tiles
local repository = require("piemenu.lib.repository").Repository.new("view")

local M = {}

local View = {}
View.__index = View
M.View = View

function View.open(name, raw_setting)
  vim.validate({name = {name, "string"}, raw_setting = {raw_setting, "table"}})

  local menus, err
  if not raw_setting.menus then
    menus, err = Menus.find(name)
  else
    menus = Menus.new(name, raw_setting)
  end
  if err then
    return err
  end

  local view_setting = menus.setting:merge(raw_setting):for_view()
  local background = Background.open(name, view_setting.position)
  local tiles = Tiles.open(menus, view_setting)

  local tbl = {name = name, _background = background, _tiles = tiles}
  local self = setmetatable(tbl, View)

  repository:set(background.window_id, self)
end

function View.highlight(self)
  local position = self._background:click()
  self._tiles:activate(position)
end

function View.finish(self)
  local position = self._background:click()
  local tile = self._tiles:find(position)

  self:close()

  if tile then
    return tile:execute_action()
  end
end

function View.close(self)
  self._background:close()
  self._tiles:close()
  repository:delete(self._background.window_id)
end

function View.get(window_id)
  vim.validate({window_id = {window_id, "number"}})
  return repository:get(window_id)
end

function View.current()
  local window_id = vim.api.nvim_get_current_win()
  local view = View.get(window_id)
  if not view then
    return nil, "not found view"
  end
  return view, nil
end

function View.find(name)
  vim.validate({name = {name, "string"}})
  for _, view in repository:all() do
    if view.name == name then
      return view
    end
  end
  return nil
end

M.hl_groups = require("piemenu.view.tile").hl_groups

return M
