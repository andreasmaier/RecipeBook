local templates = {}

local util = require("__RecipeBook__.util")

function templates.base()
  return {
    type = "frame",
    name = "RecipeBook",
    direction = "vertical",
    visible = false,
    ref = { "window" },
    actions = { on_closed = "window_closed" },
    {
      type = "flow",
      style = "flib_titlebar_flow",
      ref = { "titlebar_flow" },
      templates.frame_action_button("rb_nav_backward", { "gui.rb-nav-backward-instruction" }, "nav_backward_button"),
      templates.frame_action_button("rb_nav_forward", { "gui.rb-nav-forward-instruction" }, "nav_forward_button"),
      {
        type = "label",
        style = "frame_title",
        style_mods = { bottom_padding = 2, top_padding = -2 },
        caption = { "mod-name.RecipeBook" },
        ignored_by_interaction = true,
      },
      { type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true },
      {
        type = "textfield",
        style = "long_number_textfield",
        style_mods = { top_margin = -3 },
        visible = false,
        ref = { "search_textfield" },
        actions = {
          on_text_changed = "search_textfield_updated",
        },
      },
      templates.frame_action_button("utility/search", { "gui.rb-search-instruction" }, "search_button"),
      templates.frame_action_button(
        "rb_show_unresearched",
        { "gui.rb-show-unresearched-instruction" },
        "show_unresearched_button"
      ),
      templates.frame_action_button("rb_show_hidden", { "gui.rb-show-hidden-instruction" }, "show_hidden_button"),
      { type = "line", style_mods = { top_margin = -2, bottom_margin = 2 }, direction = "vertical" },
      templates.frame_action_button("rb_pin", { "gui.rb-pin-instruction" }, "pin_button"),
      templates.frame_action_button("utility/close", { "gui.close-instruction" }, "close_button"),
    },
    {
      type = "flow",
      style_mods = { horizontal_spacing = 12 },
      {
        type = "frame",
        style = "inside_deep_frame",
        direction = "vertical",
        {
          type = "table",
          style = "filter_group_table",
          column_count = 6,
          ref = { "filter_group_table" },
        },
        {
          type = "frame",
          style = "rb_filter_frame",
          {
            type = "frame",
            style = "rb_filter_deep_frame",
            {
              type = "scroll-pane",
              style = "rb_filter_scroll_pane",
              vertical_scroll_policy = "always",
              ref = { "filter_scroll_pane" },
            },
          },
        },
      },
      {
        type = "frame",
        style = "inside_shallow_frame",
        style_mods = { width = 500 },
        direction = "vertical",
        {
          type = "frame",
          style = "subheader_frame",
          {
            type = "sprite-button",
            style = "rb_small_transparent_slot",
            ref = { "page_header_icon" },
          },
          {
            type = "label",
            style = "caption_label",
            ref = { "page_header_label" },
          },
          { type = "empty-widget", style = "flib_horizontal_pusher" },
          {
            type = "label",
            style = "info_label",
            style_mods = { font = "default-semibold", right_margin = 8 },
            ref = { "page_header_type_label" },
          },
        },
        {
          type = "scroll-pane",
          style = "flib_naked_scroll_pane",
          style_mods = { horizontally_stretchable = true, vertically_stretchable = true },
          vertical_scroll_policy = "always",
          ref = { "page_scroll" },
        },
      },
    },
  }
end

function templates.frame_action_button(sprite, tooltip, action)
  return {
    type = "sprite-button",
    style = "frame_action_button",
    sprite = sprite .. "_white",
    hovered_sprite = sprite .. "_black",
    clicked_sprite = sprite .. "_black",
    tooltip = tooltip,
    ref = { action },
    actions = {
      on_click = action,
    },
  }
end

--- @param caption LocalisedString
--- @param objects GenericObject[]
--- @param right_caption LocalisedString?
function templates.list_box(caption, objects, right_caption)
  local num_objects = #objects
  local rows = {}
  local i = 0
  for _, object in pairs(objects) do
    if util.is_hidden(game[object.type .. "_prototypes"][object.name]) then
      num_objects = num_objects - 1
    else
      i = i + 1
      table.insert(
        rows,
        templates.prototype_button(
          object.type,
          object.name,
          "rb_list_box_row_" .. (i % 2 == 0 and "even" or "odd"),
          { "", object.amount or "", game[object.type .. "_prototypes"][object.name].localised_name },
          object.remark
        )
      )
    end
  end
  if num_objects == 0 then
    return {}
  end
  return {
    type = "flow",
    style_mods = { bottom_margin = 4 },
    direction = "vertical",
    {
      type = "flow",
      style = "centering_horizontal_flow",
      {
        type = "checkbox",
        style_mods = { font = "default-bold" },
        caption = { "", caption, " (", num_objects, ")" },
        state = false,
        actions = {
          on_checked_state_changed = "collapse_list_box",
        },
      },
      { type = "empty-widget", style = "flib_horizontal_pusher" },
      { type = "label", caption = right_caption },
    },
    {
      type = "frame",
      name = "list_frame",
      style = "deep_frame_in_shallow_frame",
      {
        type = "flow",
        style_mods = { vertical_spacing = 0 },
        direction = "vertical",
        children = rows,
      },
    },
  }
end

--- @param type string
--- @param name string
--- @param style string
--- @param caption LocalisedString
--- @param remark_caption LocalisedString?
function templates.prototype_button(type, name, style, caption, remark_caption)
  local path = type .. "/" .. name
  local remark = {}
  if remark_caption then
    -- TODO: Add "remark" capability to API to eliminate this hack
    remark = {
      type = "label",
      style_mods = {
        width = 464 - 16,
        height = 36 - 8,
        horizontal_align = "right",
        vertical_align = "center",
      },
      caption = remark_caption,
      ignored_by_interaction = true,
    }
  end
  return {
    type = "sprite-button",
    name = path,
    style = style,
    -- TODO: Add icon_horizontal_align support to sprite-buttons
    -- sprite = object.type .. "/" .. object.name,
    -- TODO: Consistent spacing
    caption = { "", "            ", caption },
    actions = { on_click = "prototype_button" },
    {
      type = "sprite-button",
      style = "rb_small_transparent_slot",
      sprite = path,
      ignored_by_interaction = true,
    },
    remark,
  }
end

return templates
