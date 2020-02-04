-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
-- INGREDIENT GUI

-- dependencies
local event = require('lualib/event')
local gui = require('lualib/gui')

-- locals
local math_max = math.max
local math_min = math.min
local table_sort = table.sort

-- self object
local self = {}

-- -----------------------------------------------------------------------------
-- HANDLERS

gui.add_handlers('ingredient', {
  generic_listbox = {
    on_gui_selection_state_changed = function(e)
      local _,_,category,object_name = e.element.get_item(e.element.selected_index):find('^%[img=(.*)/(.*)%].*$')
      event.raise(open_gui_event, {player_index=e.player_index, gui_type=category, object_name=object_name})
    end
  }
})

-- -----------------------------------------------------------------------------
-- GUI MANAGEMENT

function self.create(player, player_table, content_container, name)
  local gui_data = gui.create(content_container, 'ingredient', player.index,
    {type='flow', direction='vertical', children={
      {type='label', style='caption_label', caption={'rb-gui.usage-in-recipes'}},
      {type='flow', style={horizontal_spacing=8}, direction='horizontal', children={
        -- as ingredient
        {type='flow', direction='vertical', children={
          {type='label', style='rb_listbox_label', save_as='as_ingredient_label'},
          {type='frame', style='rb_listbox_frame', save_as='as_ingredient_frame', children={
            {type='list-box', style='rb_listbox', save_as='as_ingredient_listbox'}
          }}
        }},
        -- as product
        {type='flow', direction='vertical', children={
          {type='label', style='rb_listbox_label', save_as='as_product_label'},
          {type='frame', style='rb_listbox_frame', save_as='as_product_frame', children={
            {type='list-box', style='rb_listbox', save_as='as_product_listbox'}
          }}
        }}
      }}
    }}
  )

  -- set up data
  local ingredient_data = global.recipe_book.ingredient[name]
  local recipe_translations = player_table.dictionary.recipe.translations
  local rows = 0

  -- populate tables
  for _,mode in ipairs{'ingredient', 'product'} do
    local label = gui_data['as_'..mode..'_label']
    local listbox = gui_data['as_'..mode..'_listbox']
    local recipe_list = ingredient_data['as_'..mode]
    local recipes_len = #recipe_list
    local items = {}
    for ri=1,recipes_len do
      local recipe = recipe_list[ri]
      items[ri] = '[img=recipe/'..recipe..']  '..recipe_translations[recipe]
    end
    listbox.items = items
    label.caption = {'rb-gui.as-'..mode, recipes_len}
    rows = math_max(rows, math_min(6, recipes_len))
  end

  -- set table heights
  local height = rows * 28
  gui_data.as_ingredient_frame.style.height = height
  gui_data.as_product_frame.style.height = height

  gui.register_handlers('ingredient', 'generic_listbox', {player_index=player.index,
    gui_filters={gui_data.as_ingredient_listbox, gui_data.as_product_listbox}})

  return gui_data
end

function self.destroy(player, content_container)
  gui.destroy(content_container.children[1], 'ingredient', player.index)
end

-- -----------------------------------------------------------------------------

return self