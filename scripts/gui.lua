local flib_dictionary = require("__flib__/dictionary-lite")
local flib_gui = require("__flib__/gui-lite")
local flib_position = require("__flib__/position")
local flib_table = require("__flib__/table")
local mod_gui = require("__core__/lualib/mod-gui")

local database = require("__RecipeBook__/scripts/database")
local util = require("__RecipeBook__/scripts/util")

--- @class Context
--- @field kind ContextKind
--- @field name string
--- @field type string

--- @alias ContextKind
--- | "usage"
--- | "recipes"

--- @class GuiData
--- @field current_list DatabaseRecipe[]?
--- @field current_list_index integer
--- @field elems table<string, LuaGuiElement>
--- @field history GuiHistoryEntry[]
--- @field history_index integer
--- @field pinned boolean
--- @field player LuaPlayer
--- @field search_query string
--- @field show_hidden boolean
--- @field show_unresearched boolean

--- @class GuiHistoryEntry
--- @field context Context
--- @field recipe string

--- @class RecipeDefinition
--- @field name string
--- @field type string

local search_columns = 13
local main_panel_width = 40 * search_columns + 12
local materials_column_width = (main_panel_width - (12 * 3)) / 2
--- @type GuiLocation
local top_left_location = { x = 15, y = 58 + 15 }

-- These are needed in update_info_page
local on_prototype_button_clicked
local on_prototype_button_hovered
local on_prototype_button_left

--- @param self GuiData
local function reset_gui_location(self)
  local window = self.elems.rb_main_window
  local scale = self.player.display_scale
  window.location = flib_position.mul(top_left_location, { x = scale, y = scale })
end

--- @param self GuiData
local function update_search_results(self)
  local query = self.search_query
  local show_hidden = self.show_hidden
  local show_unresearched = self.show_unresearched
  local dictionary = flib_dictionary.get(self.player.index, "search") or {}
  local researched = global.researched_objects[self.player.force_index]
  for _, button in pairs(self.elems.search_table.children) do
    local is_researched = researched[
      button.sprite --[[@as string]]
    ]
    local is_hidden = button.tags.is_hidden
    if (show_hidden or not is_hidden) and (show_unresearched or is_researched) then
      local search_key = dictionary[button.sprite] or button.name
      local search_matched = not not string.find(string.lower(search_key), query, nil, true)
      button.visible = search_matched
      if search_matched then
        if is_hidden then
          button.style = "flib_slot_button_grey"
        elseif not is_researched then
          button.style = "flib_slot_button_red"
        else
          button.style = "flib_slot_button_default"
        end
      end
    else
      button.visible = false
    end
  end
end

--- @param obj Ingredient|Product
--- @param researched Set<string>
--- @return GuiElemDef
local function build_list_box_item(obj, researched)
  local path = obj.type .. "/" .. obj.name
  local obj_data = global.database[path]
  local style = "rb_list_box_item"
  if obj_data and obj_data.hidden then
    style = "rb_list_box_item_hidden"
  elseif not researched[path] then
    style = "rb_list_box_item_unresearched"
  end
  return {
    type = "sprite-button",
    style = style,
    sprite = path,
    caption = util.build_caption(obj),
    raise_hover_events = true,
    handler = {
      [defines.events.on_gui_click] = on_prototype_button_clicked,
      [defines.events.on_gui_hover] = on_prototype_button_hovered,
      [defines.events.on_gui_leave] = on_prototype_button_left,
    },
  }
end

--- @param self GuiData
local function update_info_page(self)
  local entry = self.history[self.history_index]
  if not entry then
    return
  end

  self.elems.search_pane.visible = false
  self.elems.info_pane.visible = true

  local researched = global.researched_objects[self.player.force_index]

  local recipe = self.current_list[self.current_list_index]
  local context = entry.context

  self.elems.info_recipe_count_label.caption = "[" .. self.current_list_index .. "/" .. #self.current_list .. "]"
  self.elems.info_context_label.sprite = context.type .. "/" .. context.name
  self.elems.info_context_label.caption =
    { "", "            ", context.kind == "recipes" and { "gui.rb-recipes" } or { "gui.rb-usage" } }
  self.elems.info_context_label.tooltip = ""

  local recipe_name_label = self.elems.info_recipe_name_label
  recipe_name_label.sprite = recipe.sprite_path
  recipe_name_label.caption = { "", "            ", recipe.localised_name }
  recipe_name_label.tooltip = ""
  if recipe.hidden then
    recipe_name_label.style = "rb_subheader_caption_button_hidden"
  elseif not researched["recipe/" .. recipe.name] then
    recipe_name_label.style = "rb_subheader_caption_button_unresearched"
  else
    recipe_name_label.style = "rb_subheader_caption_button"
  end

  local ingredients_frame = self.elems.info_ingredients_frame
  ingredients_frame.clear()
  local num_ingredients = 0
  local item_ingredients = 0
  for _, ingredient in pairs(recipe.ingredients) do
    if ingredient.type == "item" then
      item_ingredients = item_ingredients + 1
    end
    num_ingredients = num_ingredients + 1
    flib_gui.add(ingredients_frame, build_list_box_item(ingredient, researched))
  end
  self.elems.info_ingredients_count_label.caption = "[" .. num_ingredients .. "]"
  self.elems.info_ingredients_energy_label.caption = "[img=quantity-time] " .. util.format_number(recipe.energy) .. " s"

  local products_frame = self.elems.info_products_frame
  products_frame.clear()
  local num_products = 0
  for _, product in pairs(recipe.products) do
    num_products = num_products + 1
    flib_gui.add(products_frame, build_list_box_item(product, researched))
  end
  self.elems.info_products_count_label.caption = "[" .. num_products .. "]"

  local made_in_frame = self.elems.info_made_in_frame
  made_in_frame.clear()
  local num_made_in = 0
  if recipe.is_hand_craftable then
    num_made_in = num_made_in + 1
    flib_gui.add(made_in_frame, {
      type = "sprite-button",
      style = "slot_button",
      sprite = "utility/hand",
      hovered_sprite = "utility/hand_black",
      clicked_sprite = "utility/hand_black",
      number = recipe.energy,
      tooltip = { "gui.rb-handcraft" },
    })
  end
  for _, machine in pairs(recipe.made_in or {}) do
    num_made_in = num_made_in + 1
    flib_gui.add(made_in_frame, {
      type = "sprite-button",
      style = researched[machine.type .. "/" .. machine.name] and "slot_button" or "flib_slot_button_red",
      sprite = machine.type .. "/" .. machine.name,
      number = machine.amount,
      raise_hover_events = true,
      handler = {
        [defines.events.on_gui_click] = on_prototype_button_clicked,
        [defines.events.on_gui_hover] = on_prototype_button_hovered,
        [defines.events.on_gui_leave] = on_prototype_button_left,
      },
    })
  end
  self.elems.info_made_in_flow.visible = num_made_in > 0

  local unlocked_by_frame = self.elems.info_unlocked_by_frame
  unlocked_by_frame.clear()
  for technology_path in pairs(recipe.unlocked_by or {}) do
    flib_gui.add(unlocked_by_frame, {
      type = "sprite-button",
      style = global.researched_objects[self.player.force_index][technology_path] and "flib_slot_button_green"
        or "flib_slot_button_red",
      style_mods = { size = 60 },
      sprite = technology_path,
      raise_hover_events = true,
      handler = {
        [defines.events.on_gui_click] = on_prototype_button_clicked,
        [defines.events.on_gui_hover] = on_prototype_button_hovered,
        [defines.events.on_gui_leave] = on_prototype_button_left,
      },
    })
  end
  self.elems.info_unlocked_by_flow.visible = #unlocked_by_frame.children > 0
end

--- @param self GuiData
--- @param context Context?
--- @param recipe string?
--- @return boolean
local function update_list(self, context, recipe)
  if not context then
    local entry = self.history[self.history_index]
    if not entry then
      return false
    end
    context = entry.context
    recipe = entry.recipe
  end
  local list, index = database.get_recipes(self, context, recipe)
  if not list[1] or not index then
    return false
  end
  self.current_list = list
  self.current_list_index = index
  return true
end

--- @param self GuiData
--- @param context Context
--- @param recipe string?
--- @return boolean
local function show_info(self, context, recipe)
  if context.type == "entity" then
    local item_name = util.get_item_to_place(context.name)
    if not item_name then
      self.player.create_local_flying_text({ text = "No recipes to display", create_at_cursor = true })
      self.player.play_sound({ path = "utility/cannot_build" })
      return false
    end
    context.type = "item"
    context.name = item_name
  end

  local current = self.history[self.history_index]
  if current and flib_table.deep_compare(current.context, context) then
    return true
  end

  if not update_list(self, context, recipe) then
    self.player.create_local_flying_text({ text = "No recipes to display", create_at_cursor = true })
    self.player.play_sound({ path = "utility/cannot_build" })
    return false
  end

  self.history_index = self.history_index + 1
  for i = self.history_index, #self.history do
    self.history[i] = nil
  end
  self.history[self.history_index] = { context = context, self.current_list[self.current_list_index].name }

  update_info_page(self)

  return true
end

--- @param self GuiData
local function toggle_pinned(self)
  local pin_button = self.elems.pin_button
  self.pinned = not self.pinned
  if self.pinned then
    if self.player.opened == self.elems.rb_main_window then
      self.player.opened = nil
    end
    pin_button.style = "flib_selected_frame_action_button"
    pin_button.sprite = "flib_pin_black"
    self.elems.close_button.tooltip = { "gui.close" }
  else
    self.player.opened = self.elems.rb_main_window
    pin_button.style = "frame_action_button"
    pin_button.sprite = "flib_pin_white"
    self.elems.close_button.tooltip = { "gui.close-instruction" }
  end
end

--- @param e EventData.on_gui_text_changed
local function on_search_textfield_changed(e)
  local self = global.gui[e.player_index]
  if not self then
    return
  end
  self.search_query = string.lower(e.text)
  update_search_results(self)
end

--- @param e EventData.on_gui_click
on_prototype_button_clicked = function(e)
  local self = global.gui[e.player_index]
  if not self then
    return
  end
  local to_open = e.element.sprite
  local type, name = string.match(to_open, "(.-)/(.*)")
  if type == "technology" then
    self.player.open_technology_gui(name)
    return
  end

  local kind = e.button == defines.mouse_button_type.left and "recipes" or "usage"
  show_info(self, { kind = kind, name = name, type = type })
end

--- @param e EventData.on_gui_hover
on_prototype_button_hovered = function(e)
  local elem = e.element
  local tags = elem.tags
  if tags.hovering then
    return
  end
  tags.hovering = true
  elem.tags = tags
  --- @type string, string
  local type, name = string.match(elem.sprite, "(.-)/(.*)")
  elem.elem_tooltip = { type = type, name = name }
  elem.tooltip = util.build_tooltip(global.gui[e.player_index].player, type)
end

--- @param e EventData.on_gui_leave
on_prototype_button_left = function(e)
  e.element.tooltip = ""
  local tags = e.element.tags
  tags.hovering = false
  e.element.tags = tags
end

--- @param self GuiData
local function return_to_search(self)
  self.elems.info_pane.visible = false
  self.elems.search_pane.visible = true
  self.history_index = 0
  if self.player.mod_settings["rb-auto-focus-search-box"].value then
    self.elems.search_textfield.focus()
    self.elems.search_textfield.select_all()
  end
end

--- @param self GuiData
--- @param after_open_selected boolean?
local function show_gui(self, after_open_selected)
  self.player.set_shortcut_toggled("rb-toggle-gui", true)
  local window = self.elems.rb_main_window
  window.visible = true
  window.bring_to_front()
  if not self.pinned then
    self.player.opened = window
  end
  if not after_open_selected and self.player.mod_settings["rb-always-open-search"].value then
    return_to_search(self)
  end
end

--- @param self GuiData
local function hide_gui(self)
  self.player.set_shortcut_toggled("rb-toggle-gui", false)
  local window = self.elems.rb_main_window
  window.visible = false
  if self.player.opened == window then
    self.player.opened = nil
  end
  self.player.set_shortcut_toggled("rb-toggle-gui", false)
end

--- @param e EventData.on_gui_closed
local function on_main_window_closed(e)
  local self = global.gui[e.player_index]
  if not self then
    return
  end
  if self.pinned then
    return
  end
  hide_gui(self)
end

--- @param e EventData.on_gui_click
local function on_titlebar_clicked(e)
  if e.button ~= defines.mouse_button_type.middle then
    return
  end
  local self = global.gui[e.player_index]
  if not self then
    return
  end
  reset_gui_location(self)
end

--- @param e EventData.on_gui_click
local function on_close_button_clicked(e)
  local self = global.gui[e.player_index]
  if not self then
    return
  end
  hide_gui(self)
end

--- @param e EventData.on_gui_click
local function on_pin_button_clicked(e)
  local self = global.gui[e.player_index]
  if not self then
    return
  end
  toggle_pinned(self)
end

--- @param e EventData.CustomInputEvent|EventData.on_gui_click
local function on_go_back_clicked(e)
  local self = global.gui[e.player_index]
  if not self or not self.elems.rb_main_window.visible then
    return
  end
  if self.history_index <= 1 then
    return_to_search(self)
    return
  end
  self.history_index = self.history_index - 1
  update_list(self)
  update_info_page(self)
end

--- @param e EventData.CustomInputEvent|EventData.on_gui_click
local function on_go_forward_clicked(e)
  local self = global.gui[e.player_index]
  if not self or not self.elems.rb_main_window.visible then
    return
  end
  if self.history_index >= #self.history then
    return
  end
  self.history_index = self.history_index + 1
  update_list(self)
  update_info_page(self)
end

--- @param e EventData.on_gui_click
local function on_show_hidden_clicked(e)
  local self = global.gui[e.player_index]
  if not self then
    return
  end
  self.show_hidden = e.element.toggled
  e.element.sprite = self.show_hidden and "rb_show_hidden_black" or "rb_show_hidden_white"
  update_search_results(self)
  update_list(self)
  update_info_page(self)
end

--- @param e EventData.on_gui_click
local function on_show_unresearched_clicked(e)
  local self = global.gui[e.player_index]
  if not self then
    return
  end
  self.show_unresearched = e.element.toggled
  self.elems.show_unresearched_button.sprite = self.show_unresearched and "rb_show_unresearched_black"
    or "rb_show_unresearched_white"
  update_search_results(self)
  update_list(self)
  update_info_page(self)
end

--- @param e EventData.on_gui_click
local function on_recipe_nav_clicked(e)
  local self = global.gui[e.player_index]
  if not self or not self.current_list then
    return
  end
  local entry = self.history[self.history_index]
  if not entry then
    return
  end
  self.current_list_index = self.current_list_index + e.element.tags.nav_offset
  if self.current_list_index == 0 then
    self.current_list_index = #self.current_list --[[@as uint]]
  elseif self.current_list_index > #self.current_list then
    self.current_list_index = 1
  end
  entry.recipe = self.current_list[self.current_list_index].name
  update_info_page(self)
end

local hidden_item_groups = {
  ["ee-tools"] = true,
}

--- @param player LuaPlayer
--- @return GuiData
local function create_gui(player)
  local buttons = {}
  -- for _, recipe in pairs(global.database) do
  --   table.insert(buttons, {
  --     type = "sprite-button",
  --     style = recipe.hidden and "flib_slot_button_grey" or "slot_button",
  --     sprite = recipe.sprite_path,
  --     visible = not recipe.hidden,
  --     tags = { is_hidden = recipe.hidden },
  --     raise_hover_events = true,
  --     handler = {
  --       [defines.events.on_gui_click] = on_prototype_button_clicked,
  --       [defines.events.on_gui_hover] = on_prototype_button_hovered,
  --     },
  --   })
  -- end
  for _, item in pairs(game.item_prototypes) do
    local is_hidden = item.has_flag("hidden") or item.has_flag("spawnable") or hidden_item_groups[item.group.name]
    table.insert(buttons, {
      type = "sprite-button",
      style = is_hidden and "flib_slot_button_grey" or "slot_button",
      sprite = "item/" .. item.name,
      visible = not is_hidden,
      tags = { is_hidden = is_hidden },
      raise_hover_events = true,
      handler = {
        [defines.events.on_gui_click] = on_prototype_button_clicked,
        [defines.events.on_gui_hover] = on_prototype_button_hovered,
      },
    })
  end
  for _, fluid in pairs(game.fluid_prototypes) do
    local is_hidden = fluid.hidden
    table.insert(buttons, {
      type = "sprite-button",
      style = is_hidden and "flib_slot_button_grey" or "slot_button",
      sprite = "fluid/" .. fluid.name,
      visible = not is_hidden,
      tags = { is_hidden = is_hidden },
      raise_hover_events = true,
      handler = {
        [defines.events.on_gui_click] = on_prototype_button_clicked,
        [defines.events.on_gui_hover] = on_prototype_button_hovered,
      },
    })
  end
  local elems = flib_gui.add(player.gui.screen, {
    type = "frame",
    name = "rb_main_window",
    direction = "vertical",
    visible = false,
    handler = { [defines.events.on_gui_closed] = on_main_window_closed },
    {
      type = "flow",
      style = "flib_titlebar_flow",
      drag_target = "rb_main_window",
      handler = on_titlebar_clicked,
      {
        type = "label",
        style = "frame_title",
        caption = { "mod-name.RecipeBook" },
        ignored_by_interaction = true,
      },
      { type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true },
      {
        type = "sprite-button",
        name = "show_unresearched_button",
        style = "frame_action_button",
        sprite = "rb_show_unresearched_black",
        hovered_sprite = "rb_show_unresearched_black",
        clicked_sprite = "rb_show_unresearched_black",
        tooltip = { "gui.rb-show-unresearched" },
        auto_toggle = true,
        toggled = true,
        handler = on_show_unresearched_clicked,
      },
      {
        type = "sprite-button",
        name = "show_hidden_button",
        style = "frame_action_button",
        sprite = "rb_show_hidden_white",
        hovered_sprite = "rb_show_hidden_black",
        clicked_sprite = "rb_show_hidden_black",
        tooltip = { "gui.rb-show-hidden" },
        auto_toggle = true,
        handler = on_show_hidden_clicked,
      },
      {
        type = "flow",
        style = "packed_horizontal_flow",
        {
          type = "sprite-button",
          name = "go_back_button",
          style = "frame_action_button",
          sprite = "flib_nav_backward_white",
          hovered_sprite = "flib_nav_backward_black",
          clicked_sprite = "flib_nav_backward_black",
          tooltip = { "gui.rb-go-back" },
          handler = on_go_back_clicked,
        },
        {
          type = "sprite-button",
          name = "go_forward_button",
          style = "frame_action_button",
          sprite = "flib_nav_forward_white",
          hovered_sprite = "flib_nav_forward_black",
          clicked_sprite = "flib_nav_forward_black",
          tooltip = { "gui.rb-go-forward" },
          handler = on_go_forward_clicked,
        },
      },
      {
        type = "sprite-button",
        name = "pin_button",
        style = "frame_action_button",
        sprite = "flib_pin_white",
        hovered_sprite = "flib_pin_black",
        clicked_sprite = "flib_pin_black",
        tooltip = { "gui.flib-keep-open" },
        handler = on_pin_button_clicked,
      },
      {
        type = "sprite-button",
        name = "close_button",
        style = "frame_action_button",
        sprite = "utility/close_white",
        hovered_sprite = "utility/close_black",
        clicked_sprite = "utility/close_black",
        tooltip = { "gui.close-instruction" },
        handler = on_close_button_clicked,
      },
    },
    {
      type = "frame",
      name = "search_pane",
      style = "inside_deep_frame",
      direction = "vertical",
      {
        type = "frame",
        style = "subheader_frame",
        style_mods = { horizontally_stretchable = true },
        { type = "label", style = "subheader_caption_label", caption = { "gui.rb-search" } },
        { type = "empty-widget", style = "flib_horizontal_pusher" },
        {
          type = "textfield",
          name = "search_textfield",
          lose_focus_on_confirm = true,
          clear_and_focus_on_right_click = true,
          handler = { [defines.events.on_gui_text_changed] = on_search_textfield_changed },
        },
      },
      {
        type = "scroll-pane",
        style = "rb_search_scroll_pane",
        style_mods = { maximal_height = main_panel_width, width = main_panel_width },
        {
          type = "table",
          name = "search_table",
          style = "slot_table",
          column_count = search_columns,
          children = buttons,
        },
      },
    },
    {
      type = "frame",
      name = "info_pane",
      style = "inside_shallow_frame",
      style_mods = { width = main_panel_width },
      direction = "vertical",
      visible = false,
      {
        type = "frame",
        style = "subheader_frame",
        style_mods = { horizontally_stretchable = true },
        {
          type = "sprite-button",
          name = "info_recipe_name_label",
          style = "rb_subheader_caption_button",
          style_mods = { horizontally_squashable = true },
          enabled = false,
          raise_hover_events = true,
          handler = { [defines.events.on_gui_hover] = on_prototype_button_hovered },
        },
        { type = "empty-widget", style = "flib_horizontal_pusher" },
        {
          type = "sprite-button",
          name = "info_context_label",
          style = "rb_subheader_caption_button",
          enabled = false,
          raise_hover_events = true,
          handler = { [defines.events.on_gui_hover] = on_prototype_button_hovered },
        },
        {
          type = "label",
          name = "info_recipe_count_label",
          style = "info_label",
          style_mods = {
            font = "default-semibold",
            right_margin = 4,
            single_line = true,
            horizontally_squashable = false,
          },
        },
        {
          type = "sprite-button",
          style = "tool_button",
          style_mods = { padding = 0, size = 24, top_margin = 1 },
          sprite = "flib_nav_backward_black",
          tooltip = "Previous recipe",
          tags = { nav_offset = -1 },
          handler = on_recipe_nav_clicked,
        },
        {
          type = "sprite-button",
          style = "tool_button",
          style_mods = { padding = 0, size = 24, top_margin = 1, right_margin = 4 },
          sprite = "flib_nav_forward_black",
          tooltip = "Next recipe",
          tags = { nav_offset = 1 },
          handler = on_recipe_nav_clicked,
        },
      },
      {
        type = "flow",
        style_mods = { padding = 12, top_padding = 8, vertical_spacing = 12 },
        direction = "vertical",
        {
          type = "flow",
          style_mods = { horizontal_spacing = 12 },
          {
            type = "flow",
            style_mods = { width = materials_column_width },
            direction = "vertical",
            {
              type = "flow",
              { type = "label", style = "caption_label", caption = { "gui.rb-ingredients" } },
              {
                type = "label",
                name = "info_ingredients_count_label",
                style = "info_label",
                style_mods = { font = "default-semibold" },
              },
              { type = "empty-widget", style = "flib_horizontal_pusher" },
              { type = "label", name = "info_ingredients_energy_label", style_mods = { font = "default-semibold" } },
            },
            {
              type = "frame",
              name = "info_ingredients_frame",
              style = "deep_frame_in_shallow_frame",
              style_mods = { width = materials_column_width, minimal_height = 1 },
              direction = "vertical",
            },
          },
          {
            type = "flow",
            style_mods = { width = materials_column_width },
            direction = "vertical",
            {
              type = "flow",
              { type = "label", style = "caption_label", caption = { "gui.rb-products" } },
              {
                type = "label",
                name = "info_products_count_label",
                style = "info_label",
                style_mods = { font = "default-semibold" },
              },
            },
            {
              type = "frame",
              name = "info_products_frame",
              style = "deep_frame_in_shallow_frame",
              style_mods = { width = materials_column_width, minimal_height = 1 },
              direction = "vertical",
            },
          },
        },
        {
          type = "flow",
          name = "info_made_in_flow",
          style_mods = { vertical_align = "center", horizontal_spacing = 12 },
          { type = "label", style = "caption_label", caption = { "gui.rb-made-in" } },
          {
            type = "frame",
            style = "slot_button_deep_frame",
            { type = "table", name = "info_made_in_frame", style = "slot_table", column_count = 11 },
          },
        },
        {
          type = "flow",
          name = "info_unlocked_by_flow",
          style_mods = { vertical_align = "center", horizontal_spacing = 12 },
          { type = "label", style = "caption_label", caption = { "gui.rb-unlocked-by" } },
          {
            type = "frame",
            style = "slot_button_deep_frame",
            { type = "table", name = "info_unlocked_by_frame", style = "slot_table", column_count = 11 },
          },
        },
      },
    },
  })

  --- @type GuiData
  local self = {
    current_list_index = 0,
    elems = elems,
    history = {},
    history_index = 0,
    pinned = false,
    player = player,
    search_query = "",
    show_hidden = false,
    show_unresearched = true,
  }
  global.gui[player.index] = self

  reset_gui_location(self)
  update_search_results(self)

  return self
end

local allowed_types = {
  entity = true,
  fluid = true,
  item = true,
}

--- @param e EventData.CustomInputEvent
local function on_open_selected(e)
  local player = game.get_player(e.player_index)
  if not player then
    return
  end
  local selected = e.selected_prototype
  if not selected then
    return
  end

  local type = selected.base_type
  --- @type string?
  local name = selected.name
  local recipe_name
  if type == "recipe" then
    recipe_name = selected.name
    local recipe = game.recipe_prototypes[recipe_name]
    local product = recipe.main_product or recipe.products[1]
    if not product then
      return
    end
    type = product.type
    name = product.name
  end

  if not name or not allowed_types[type] then
    return
  end

  local self = global.gui[e.player_index]
  if not self then
    self = create_gui(player)
  end
  -- Auto-pin if another GUI is already open
  if
    player.opened_gui_type ~= defines.gui_type.none
    and player.opened ~= self.elems.rb_main_window
    and not self.pinned
  then
    toggle_pinned(self)
  end
  if show_info(self, { kind = "recipes", name = name, type = type }, recipe_name) then
    show_gui(self, true)
  end
end

--- @param e EventData.CustomInputEvent|EventData.on_lua_shortcut|EventData.on_gui_click
local function on_gui_toggle(e)
  if e.prototype_name and e.prototype_name ~= "rb-toggle-gui" then
    return
  end
  local player = game.get_player(e.player_index)
  if not player then
    return
  end
  local self = global.gui[e.player_index]
  if not self then
    self = create_gui(player)
  end
  if self.elems.rb_main_window.visible then
    hide_gui(self)
  else
    show_gui(self)
  end
end

local function on_tick()
  for player_index in pairs(global.refresh_gui) do
    local self = global.gui[player_index]
    if self then
      update_search_results(self)
      update_info_page(self)
    end
    global.refresh_gui[player_index] = nil
  end
end

--- @param player LuaPlayer
local function refresh_mod_gui_button(player)
  local button_flow = mod_gui.get_button_flow(player)
  local existing = button_flow.rb_mod_gui_button
  if existing then
    existing.destroy()
  end
  if not player.mod_settings["rb-show-overhead-button"].value then
    return
  end
  flib_gui.add(button_flow, {
    type = "sprite-button",
    name = "rb_mod_gui_button",
    style = mod_gui.button_style,
    style_mods = { padding = 8 },
    sprite = "rb_mod_gui_icon",
    tooltip = { "gui.rb-mod-gui-button-tooltip" },
    handler = { [defines.events.on_gui_click] = on_gui_toggle },
  })
end

--- @param e EventData.on_player_created
local function on_player_created(e)
  local player = game.get_player(e.player_index)
  if not player then
    return
  end
  -- create_gui(player)
  refresh_mod_gui_button(player)
end

--- @param e EventData.on_runtime_mod_setting_changed
local function on_runtime_mod_setting_changed(e)
  if e.setting ~= "rb-show-overhead-button" then
    return
  end
  local player = game.get_player(e.player_index)
  if not player then
    return
  end
  refresh_mod_gui_button(player)
end

local gui = {}

gui.on_init = function()
  --- @type table<uint, GuiData?>
  global.gui = {}
  --- @type Set<uint>
  global.refresh_gui = {}
  util.build_dictionaries()

  for _, player in pairs(game.players) do
    refresh_mod_gui_button(player)
  end
end
gui.on_configuration_changed = function()
  util.build_dictionaries()
  for _, player in pairs(game.players) do
    refresh_mod_gui_button(player)
  end
  for _, gui in pairs(global.gui) do
    if gui.elems.rb_main_window.valid then
      gui.elems.rb_main_window.destroy()
    end
  end
  global.gui = {}
end

gui.events = {
  [defines.events.on_lua_shortcut] = on_gui_toggle,
  [defines.events.on_player_created] = on_player_created,
  [defines.events.on_runtime_mod_setting_changed] = on_runtime_mod_setting_changed,
  [defines.events.on_tick] = on_tick,
  ["rb-go-back"] = on_go_back_clicked,
  ["rb-go-forward"] = on_go_forward_clicked,
  ["rb-open-selected"] = on_open_selected,
  ["rb-toggle-gui"] = on_gui_toggle,
  [util.refresh_guis_paused_event] = on_tick,
}

flib_gui.add_handlers({
  on_close_button_clicked = on_close_button_clicked,
  on_gui_toggle = on_gui_toggle,
  on_main_window_closed = on_main_window_closed,
  on_nav_backward_clicked = on_go_back_clicked,
  on_nav_forward_clicked = on_go_forward_clicked,
  on_pin_button_clicked = on_pin_button_clicked,
  on_prototype_button_clicked = on_prototype_button_clicked,
  on_prototype_button_hovered = on_prototype_button_hovered,
  on_recipe_nav_clicked = on_recipe_nav_clicked,
  on_search_textfield_changed = on_search_textfield_changed,
  on_show_hidden_clicked = on_show_hidden_clicked,
  on_show_unresearched_clicked = on_show_unresearched_clicked,
  on_titlebar_clicked = on_titlebar_clicked,
})

-- Placeholder for now
remote.add_interface("RecipeBook", {
  open_page = function() end,
})

return gui
