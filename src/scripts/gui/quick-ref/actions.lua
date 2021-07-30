local gui = require("__flib__.gui-beta")

local shared = require("scripts.shared")
local util = require("scripts.util")

local actions = {}

function actions.bring_all_to_front(player_table)
  for _, gui_data in pairs(player_table.guis.quick_ref) do
    gui_data.refs.window.bring_to_front()
  end
end

function actions.close(data)
  local msg = data.msg

  data.refs.window.destroy()
  data.player_table.guis.quick_ref[msg.id] = nil
  -- TODO: Shared can go away!
  shared.update_header_button(
    data.player,
    data.player_table,
    {class = "recipe", name = msg.id},
    "quick_ref_button",
    false
  )
end

function actions.handle_button_click(data)
  local e = data.e

  if e.alt then
    local button = e.element
    local style = button.style.name
    if style == "flib_slot_button_green" then
      button.style = gui.get_tags(button).previous_style
    else
      gui.update_tags(button, {previous_style = style})
      button.style = "flib_slot_button_green"
    end
  else
    local context = util.navigate_to(e)
    if context then
      shared.open_page(data.player, data.player_table, context)
    end
  end
end

function actions.view_details(data)
  shared.open_page(data.player, data.player_table, {class = "recipe", name = data.msg.id})
end

return actions
