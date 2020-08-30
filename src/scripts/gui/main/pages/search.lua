local search_page = {}

local gui = require("__flib__.gui")

local constants = require("constants")
local formatter = require("scripts.formatter")

local string = string

gui.add_handlers{
  search = {
    category_drop_down = {
      on_gui_selection_state_changed = function(e)
        local player_table = global.players[e.player_index]
        player_table.gui.main.search.category = constants.search_categories[e.element.selected_index]
        gui.handlers.search.textfield.on_gui_text_changed(e)
      end
    },
    textfield = {
      on_gui_text_changed = function(e)
        local player = game.get_player(e.player_index)
        local player_table = global.players[e.player_index]
        local gui_data = player_table.gui.main.search
        local query = string.lower(gui_data.textfield.text)

        local category = gui_data.category
        local translations = player_table.translations[gui_data.category]
        local scroll = gui_data.results_scroll_pane
        local rb_data = global.recipe_book[category]

        -- hide limit frame, show it again later if there's more than 50 results
        local limit_frame = gui_data.limit_frame
        limit_frame.visible = false

        -- don't show anything if there are zero or one letters in the query
        if string.len(query) < 2 then
          scroll.clear()
          return
        end

        -- fuzzy search
        if player_table.settings.use_fuzzy_search then
          query = string.gsub(query, ".", "%1.*")
        end

        -- input sanitization
        for pattern, replacement in pairs(constants.input_sanitisers) do
          query = string.gsub(query, pattern, replacement)
        end

        gui_data.query = query

        -- settings and player data
        local player_data = {
          force_index = player.force.index,
          player_index = player.index,
          settings = player_table.settings,
          translations = player_table.translations
        }

        -- match queries and add or modify children
        local match_internal = player_table.settings.use_internal_names
        local children = scroll.children
        local add = scroll.add
        local i = 0
        for internal, translation in pairs(translations) do
          if string.find(string.lower(match_internal and internal or translation), query) then
            local obj_data = rb_data[internal]
            local should_add, style, caption, tooltip = formatter(obj_data, player_data)
            if should_add then
              i = i + 1
              -- create or modify element
              local child = children[i]
              if child then
                child.style = style
                child.caption = caption
                child.tooltip = tooltip
              else
                add{type="button", name="rb_list_box_item__"..i, style=style, caption=caption, tooltip=tooltip}
              end

              if i == constants.search_results_limit then
                limit_frame.visible = true
                break
              end
            end
          end
        end

        -- remove extraneous children, if any
        if i < constants.search_results_limit then
          for j = i + 1, #scroll.children do
            children[j].destroy()
          end
        end

        -- * ---------------------------------------------------------------------------
      end
    }
  }
}

function search_page.build()
  return {
    {type="frame", style="subheader_frame", children={
      {type="label", style="subheader_caption_label", caption={"rb-gui.search-by"}},
      {template="pushers.horizontal"},
      {type="drop-down", items=constants.search_categories_localised, selected_index=2, handlers="search.category_drop_down",
        save_as="search.category_drop_down"}
    }},
    {type="flow", style="rb_search_content_flow", direction="vertical", children={
      {type="textfield", style="rb_search_textfield", clear_and_focus_on_right_click=true, handlers="search.textfield", save_as="search.textfield"},
      {type="frame", style="rb_search_results_frame", direction="vertical", children={
        {type="frame", style="rb_search_results_subheader_frame", elem_mods={visible=false}, save_as="search.limit_frame", children={
          {type="label", style="info_label", caption={"", "[img=info] ", {"rb-gui.results-limited", constants.search_results_limit}}}
        }},
        {type="scroll-pane", style="rb_search_results_scroll_pane", save_as="search.results_scroll_pane"}
      }}
    }}
  }
end

function search_page.setup(player, player_table, gui_data)
  gui_data.search.category = "recipe"
  return gui_data
end

return search_page