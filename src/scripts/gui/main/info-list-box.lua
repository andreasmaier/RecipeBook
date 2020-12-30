local formatter = require("scripts.formatter")
local util = require("scripts.util")

local info_list_box = {}

function info_list_box.build(caption, rows, save_location)
  return (
    {type = "flow", direction = "vertical", ref = util.append(save_location, "flow"), children = {
      {type = "label", style = "rb_info_list_box_label", caption = caption, ref = util.append(save_location, "label")},
      {type = "frame", style = "deep_frame_in_shallow_frame", ref = util.append(save_location, "frame"),  children = {
        {
          type = "scroll-pane",
          style = "rb_list_box_scroll_pane",
          style_mods = {height = (rows * 28)},
          ref = util.append(save_location, "scroll_pane")
        }
      }}
    }}
  )
end

function info_list_box.update(tbl, int_class, list_box, player_data, always_show, starting_index)
  starting_index = starting_index or 0
  local recipe_book = global.recipe_book[int_class]

  -- scroll pane
  local scroll = list_box.scroll_pane
  local add = scroll.add
  local children = scroll.children

  -- loop through input table
  local i = starting_index
  for j = 1, #tbl do
    -- get object information
    local obj = tbl[j]
    local obj_data
    if int_class == "material" then
      obj_data = recipe_book[obj.type.."."..obj.name]
    elseif int_class == "crafter" then
      obj_data = recipe_book[obj.name]
    else
      obj_data = recipe_book[obj]
    end
    local should_add, style, caption, tooltip, enabled = formatter(
      obj_data,
      player_data,
      obj.amount_string,
      always_show
    )

    if should_add then
      i = i + 1
      -- update or add item
      local item = children[i]
      if item then
        item.style = style
        item.caption = caption
        item.tooltip = tooltip
        item.enabled = enabled
      else
        add{
          type = "button",
          style = style,
          caption = caption,
          tooltip = tooltip,
          enabled = enabled,
          tags = {
            [script.mod_name] = {
              flib = {
                on_click = {gui = "main", action = "handle_list_box_item_click"}
              }
            }
          }
        }
      end
    end
  end
  -- destroy extraneous items
  for j = i + 1, #children do
    children[j].destroy()
  end

  -- set listbox properties
  if i == 0 then
    list_box.flow.visible = false
  else
    list_box.flow.visible = true
    scroll.style.height = math.min((28 * i), (28 * 6))

    local caption = list_box.label.caption
    caption[2] = i - starting_index
    list_box.label.caption = caption
  end
end


-- only used on the home screen
function info_list_box.update_home(tbl_name, gui_data, player_data, home_data)
  local recipe_book = global.recipe_book
  local tbl = home_data[tbl_name]

  -- list box
  local list_box = gui_data.refs.home[tbl_name]
  local scroll = list_box.scroll_pane
  local add = scroll.add
  local children = scroll.children

  -- loop through input table
  local i = 0
  for j = 1, #tbl do
    -- get object information
    local entry = tbl[j]
    if entry.int_class ~= "home" then
      local obj_data = recipe_book[entry.int_class][entry.int_name]
      local should_add, style, caption, tooltip = formatter(obj_data, player_data)

      if should_add then
        i = i + 1
        -- add or update item
        local item = children[i]
        if item then
          item.style = style
          item.caption = caption
          item.tooltip = tooltip
        else
          add{
            type = "button",
            style = style,
            caption = caption,
            tooltip = tooltip,
            tags = {
              [script.mod_name] = {
                flib = {
                  on_click = {gui = "main", action = "handle_list_box_item_click"}
                }
              }
            }
          }
        end
      end
    end
  end

  -- destroy extraneous items
  for j = i + 1, #children do
    children[j].destroy()
  end
end

-- TODO: move this to flib
-- get the width and height of an area
local function area_dimensions(area)
  local width = math.abs(area.left_top.x - area.right_bottom.x)
  local height = math.abs(area.left_top.y - area.right_bottom.y)
  return width, height
end

-- if values are returned, the corresponding page is opened
function info_list_box.handle_click(e, player, player_table)
  local _, _, class, name = string.find(e.element.caption, "^.-%[img=(.-)/(.-)%]  .*$")
  if class == "technology" then
    player_table.flags.technology_gui_open = true
    player.open_technology_gui(name)
  elseif class == "entity" then
    if e.shift then
      local crafter_data = global.recipe_book.crafter[name]
      if crafter_data and crafter_data.fixed_recipe then
        return "recipe", crafter_data.fixed_recipe
      end
    else
      local recipe_name = player_table.guis.main.state.open_page.name
      local cursor_stack = player.cursor_stack
      player.clear_cursor()
      if cursor_stack and cursor_stack.valid then
        -- entities with an even number of tiles to a side need to be set at -0.5 instead of 0
        local width, height = area_dimensions(game.entity_prototypes[name].collision_box)
        cursor_stack.set_stack{name = "blueprint", count = 1}
        cursor_stack.set_blueprint_entities{
          {
            entity_number = 1,
            name = name,
            position = {
              math.ceil(width) % 2 == 0 and -0.5 or 0,
              math.ceil(height) % 2 == 0 and -0.5 or 0
            },
            recipe = recipe_name
          }
        }
        player.add_to_clipboard(cursor_stack)
        player.activate_paste()
      end
    end
  else
    return class, name
  end
end

return info_list_box
