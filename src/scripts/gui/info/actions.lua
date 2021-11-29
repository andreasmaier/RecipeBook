local math = require("__flib__.math")
local on_tick_n = require("__flib__.on-tick-n")

local constants = require("constants")

local gui_util = require("scripts.gui.util")
local recipe_book = require("scripts.recipe-book")
local shared = require("scripts.shared")

local quick_ref_gui = require("scripts.gui.quick-ref.index")

local actions = {}

local root = require("scripts.gui.info.root")

function actions.get_action_data(msg, e)
  -- Get info
  local player = game.get_player(e.player_index)
  local player_table = global.players[e.player_index]

  local gui_data = player_table.guis.info[msg.id]
  if not gui_data then
    return
  end

  local state = gui_data.state
  local context = state.history[state.history._index]

  -- Mark this GUI as active
  -- NOTE: This works because if we're getting action data, we're about to do an action
  player_table.guis.info._active_id = msg.id

  return {
    context = context,
    e = e,
    gui_data = gui_data,
    msg = msg,
    player = player,
    player_table = player_table,
    refs = gui_data.refs,
    state = gui_data.state,
  }
end

function actions.set_as_active(data)
  data.player_table.guis.info._active_id = data.state.id
end

function actions.reset_location(data)
  if data.e.button == defines.mouse_button_type.middle then
    data.refs.window.force_auto_center()
  end
end

function actions.close(data)
  root.destroy(data.player_table, data.msg.id)
end

function actions.bring_to_front(data)
  if not data.state.docked then
    data.refs.window.bring_to_front()
  end
end

function actions.toggle_search(data)
  local state = data.state
  local refs = data.refs

  local opened = state.search_opened
  state.search_opened = not opened

  local search_button = refs.titlebar.search_button
  local search_textfield = refs.titlebar.search_textfield
  if opened then
    search_button.sprite = "utility/search_white"
    search_button.style = "frame_action_button"
    search_textfield.visible = false

    if state.search_query ~= "" then
      -- Reset query
      search_textfield.text = ""
      state.search_query = ""
      -- Refresh page
      root.update_contents(data.player, data.player_table, data.msg.id)
    end
  else
    -- Show search textfield
    search_button.sprite = "utility/search_black"
    search_button.style = "flib_selected_frame_action_button"
    search_textfield.visible = true
    search_textfield.focus()
  end
end

function actions.navigate(data)
  -- Update position in history
  local delta = data.msg.delta
  local history = data.state.history
  if data.e.shift then
    if delta < 0 then
      history._index = 1
    else
      history._index = #history
    end
  else
    history._index = math.clamp(history._index + delta, 1, #history)
  end
  -- Update contents
  root.update_contents(data.player, data.player_table, data.msg.id)
end

function actions.update_search_query(data)
  local player = data.player
  local player_table = data.player_table
  local state = data.state
  local id = data.msg.id

  local query = string.lower(data.e.element.text)
  -- Fuzzy search
  if player_table.settings.general.search.fuzzy_search then
    query = string.gsub(query, ".", "%1.*")
  end
  -- Input sanitization
  for pattern, replacement in pairs(constants.input_sanitizers) do
    query = string.gsub(query, pattern, replacement)
  end
  -- Save query
  state.search_query = query

  -- Remove scheduled update if one exists
  if state.update_results_ident then
    on_tick_n.remove(state.update_results_ident)
    state.update_results_ident = nil
  end

  if query == "" then
    -- Update now
    root.update_contents(player, player_table, id, { refresh = true })
  else
    -- Update in a while
    state.update_results_ident = on_tick_n.add(
      game.tick + constants.search_timeout,
      { gui = "info", id = id, action = "update_search_results", player_index = data.e.player_index }
    )
  end
end

function actions.update_search_results(data)
  -- Update based on query
  root.update_contents(data.player, data.player_table, data.msg.id, { refresh = true })
end

function actions.navigate_to(data)
  local e = data.e
  local context = gui_util.navigate_to(e)
  if context then
    if e.button == defines.mouse_button_type.middle then
      root.build(data.player, data.player_table, context)
    else
      root.update_contents(data.player, data.player_table, data.msg.id, { new_context = context })
    end
  end
end

function actions.navigate_to_plain(data)
  local msg = data.msg
  root.update_contents(data.player, data.player_table, msg.id, { new_context = msg.context })
end

function actions.open_in_tech_window(data)
  data.player_table.flags.technology_gui_open = true
  data.player.open_technology_gui(data.context.name)
end

function actions.go_to_base_fluid(data)
  local base_fluid = recipe_book.fluid[data.context.name].prototype_name
  root.update_contents(data.player, data.player_table, data.msg.id, { class = "fluid", name = base_fluid })
end

function actions.toggle_quick_ref(data)
  local state = data.state
  if not (state.docked and not state.search_info) then
    local sizes = constants.gui_sizes[data.player_table.language] or constants.gui_sizes.en
    local offset = sizes.info_width + (state.search_info and (sizes.search_width + 24) or 0)
    offset = offset * data.player.display_scale
    local location = data.refs.root.location
    quick_ref_gui.toggle(data.player, data.player_table, data.context.name, { location.x + offset, y = location.y })
  end
end

function actions.toggle_favorite(data)
  local player_table = data.player_table
  local favorites = player_table.favorites
  local context = data.context
  local combined_name = context.class .. "." .. context.name
  local to_state
  if favorites[combined_name] then
    to_state = false
    favorites[combined_name] = nil
  else
    -- Copy the table instead of passing a reference
    favorites[combined_name] = { class = context.class, name = context.name }
    to_state = true
  end
  shared.update_header_button(data.player, player_table, context, "favorite_button", to_state)
end

function actions.update_header_button(data)
  local msg = data.msg
  local button = data.refs.header[msg.button]
  if msg.to_state then
    button.style = "flib_selected_tool_button"
    button.tooltip = constants.header_button_tooltips[msg.button].selected
  else
    button.style = "tool_button"
    button.tooltip = constants.header_button_tooltips[msg.button].unselected
  end
end

function actions.open_list(data)
  local msg = data.msg
  local list_context = msg.context
  local source = msg.source
  local list = recipe_book[list_context.class][list_context.name][source]
  if list and #list > 0 then
    local first_obj = list[1]
    shared.open_page(data.player, data.player_table, {
      class = first_obj.class,
      name = first_obj.name,
      list = {
        context = list_context,
        index = 1,
        source = source,
      },
    })
  end
end

function actions.toggle_collapsed(data)
  local msg = data.msg
  local context = msg.context
  local component_index = msg.component_index
  local component_ident = constants.pages[context.class][component_index]
  if component_ident then
    local state = data.state.components[component_index]
    if state then
      state.collapsed = not state.collapsed
      root.update_contents(data.player, data.player_table, msg.id, { refresh = true })
    end
  end
end

function actions.change_tech_level(data)
  local context = data.context
  local msg = data.msg
  local state = data.state

  local context_data = recipe_book[context.class][context.name]
  local min = context_data.min_level
  local max = context_data.max_level
  local new_level = math.clamp(state.selected_tech_level + msg.delta, min, max)
  if new_level ~= state.selected_tech_level then
    state.selected_tech_level = new_level
    root.update_contents(data.player, data.player_table, msg.id, { refresh = true })
  end
end

function actions.detach_window(data)
  local state = data.state
  -- Just in case
  if not state.docked then
    return
  end

  local context = state.history[state.history._index]

  -- Close this GUI and create a detached one
  actions.close(data)
  shared.open_page(data.player, data.player_table, context)
end

function actions.print_object(data)
  local context = data.context
  local obj_data = recipe_book[context.class][context.name]

  if obj_data then
    if __DebugAdapter then
      __DebugAdapter.print(obj_data)
      data.player.print("Object data has been printed to the debug console.")
    else
      log(serpent.block(obj_data))
      data.player.print("Object data has been printed to the log file.")
    end
  end
end

return actions
