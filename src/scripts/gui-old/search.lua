local search_gui = {}

local event = require("__flib__.event")
local gui = require("__flib__.gui")

local constants = require("scripts.constants")
local search = require("scripts.search")
local on_tick = require("scripts.on-tick")

local math = math
local string = string

gui.add_handlers{search={
  close_button = {
    on_gui_click = function(e)
      search_gui.close(game.get_player(e.player_index), global.players[e.player_index])
    end
  },
  search_textfield = {
    on_gui_click = function(e)
      local player_table = global.players[e.player_index]
      local gui_data = player_table.gui.search
      -- reset GUI state
      gui_data.results_listbox.selected_index = 0
      gui_data.state = "search"
      gui_data.search_textfield.focus()
      game.get_player(e.player_index).opened = gui_data.search_textfield
    end,
    on_gui_closed = function(e)
      local player_table = global.players[e.player_index]
      local gui_data = player_table.gui.search
      if gui_data.state == "search" then
        gui_data.category_dropdown.style = "rb_active_dropdown"
        gui_data.state = "select_category"
        gui_data.category_dropdown.focus()
        game.get_player(e.player_index).opened = gui_data.category_dropdown
      end
    end,
    on_gui_confirmed = function(e)
      local player_table = global.players[e.player_index]
      local gui_data = player_table.gui.search
      local results_listbox = gui_data.results_listbox
      -- don't do anything if the listbox is empty
      if #results_listbox.items == 0 then return end
      -- set initial selected index
      results_listbox.selected_index = 1
      -- set GUI state
      gui_data.state = "select_result"
      game.get_player(e.player_index).opened = gui_data.results_listbox
      results_listbox.focus()
    end,
    on_gui_text_changed = function(e)
      local player_table = global.players[e.player_index]
      if player_table.flags.searching then
        search.cancel(e.player_index, player_table)
      end

      local query = string.lower(e.text)
      -- fuzzy search
      if player_table.settings.use_fuzzy_search then
        query = string.gsub(query, ".", "%1.*")
      end
      -- input sanitization
      for pattern, replacement in pairs(constants.input_sanitizers) do
        query = string.gsub(query, pattern, replacement)
      end

      player_table.gui.search.query = query

      search.start(e.player_index, player_table, e.selected_index)
      on_tick.update()
    end
  },
  results_listbox = {
    on_gui_closed = function(e)
      gui.handlers.search.search_textfield.on_gui_click(e)
    end,
    on_gui_selection_state_changed = function(e)
      local player_table = global.players[e.player_index]
      local gui_data = player_table.gui.search
      if e.keyboard_confirm or gui_data.state ~= "select_result" then
        local _,_,object_class,object_name = e.element.get_item(e.element.selected_index):find("^.-%[img=(.-)/(.-)%].*$")
        local category = gui_data.category
        if gui_data.category == "material" then
          object_name = {object_class, object_name}
        end
        gui_data.state = "selected_result"
        event.raise(constants.open_gui_event, {player_index=e.player_index, gui_type=category, object=object_name, source_data={mod_name="RecipeBook",
          gui_name="search", category=gui_data.category, query=gui_data.search_textfield.text, selected_index=e.element.selected_index}})
        search_gui.close(game.get_player(e.player_index), player_table)
      end
    end
  },
  category_dropdown = {
    on_gui_selection_state_changed = function(e, new_category)
      local player_table = global.players[e.player_index]
      local gui_data = player_table.gui.search
      -- update GUI state
      gui_data.category = new_category or constants.category_by_index[e.element.selected_index]
      if gui_data.state == "search" then
        gui_data.search_textfield.focus()
        gui.handlers.search.search_textfield.on_gui_text_changed{player_index=e.player_index, text=gui_data.search_textfield.text}
      elseif gui_data.state == "select_category" then
        gui.handlers.search.search_textfield.on_gui_text_changed{player_index=e.player_index, text=gui_data.search_textfield.text}
      else
        game.get_player(e.player_index).opened = gui_data.search_textfield
      end
    end,
    -- TODO close logic breaks when switching controllers
    on_gui_closed = function(e)
      local player_table = global.players[e.player_index]
      -- temporary error catching - print a butt-ton of data to script_output, then crash
      if not player_table.gui.search then
        local tables = {
          global_data = global.__lualib.event,
          players = {}
        }
        for i,t in pairs(global.players) do
          tables.players[i] = {
            flags = t.flags,
            history = t.history,
            gui = t.gui,
            settings = t.settings
          }
        end
        game.write_file("RecipeBook/crash_dump_"..game.tick..".log", serpent.block(tables))
        error([[

RECIPE BOOK: A FATAL ERROR HAS OCCURED.
Please gather the following and report it to the mod author on GitHub:
  - Your savegame
  - The crash dump. This can be found in your Factorio install directory, under "script-output/RecipeBook/crash_dump_(gametick).log".
  - A description of exactly what you (and any other players on the server) were doing at the time of the crash.
]]
        )
      end
      if player_table.gui.search.state == "select_category" then
        search_gui.close(game.get_player(e.player_index), player_table)
      else
        e.element.style = "dropdown"
      end
    end
  }
}}

function search_gui.open(player, player_table, options)
  options = options or {}
  local category = options.category or player_table.settings.default_category
  -- create GUI structure
  local gui_data = gui.build(player.gui.screen, {
    {type="frame", name="rb_search_window", style="dialog_frame", direction="vertical", save_as="window", children={
      -- titlebar
      {type="flow", style="rb_titlebar_flow", children={
        {type="label", style="frame_title", caption={"mod-name.RecipeBook"}},
        {type="empty-widget", style="rb_titlebar_draggable_space", save_as="drag_handle"},
        {template="close_button", handlers="search.close_button"}
      }},
      {type="frame", style="window_content_frame_packed", direction="vertical", children={
        -- toolbar
        {type="frame", style="subheader_frame", children={
          {type="label", style="subheader_caption_label", caption={"rb-gui.search-by"}},
          {template="pushers.horizontal"},
          {type="drop-down", items={{"rb-gui.material"}, {"rb-gui.recipe"}}, selected_index=constants.category_to_index[category],
            handlers="search.category_dropdown", save_as="category_dropdown"}
        }},
        -- search bar
        {type="textfield", style_mods={width=225, margin=8, bottom_margin=0}, clear_and_focus_on_right_click=true, handlers="search.search_textfield",
          save_as="search_textfield"},
        -- results listbox
        {type="frame", style="rb_search_results_listbox_frame", style_mods={margin=8}, children={
          {type="list-box", style="rb_listbox_for_keyboard_nav", handlers="search.results_listbox", save_as="results_listbox"},
          {type="frame", style="rb_blurry_frame", mods={visible=false}, save_as="results_cover_frame", children={
            {type="flow", style_mods={horizontally_stretchable=true, vertically_stretchable=true, horizontal_align="center", vertical_align="center"}, children={
              {type="label", style="bold_label", save_as="results_cover_label"}
            }}
          }}
        }}
      }}
    }}
  })
  -- screen data
  gui_data.drag_handle.drag_target = gui_data.window
  gui_data.window.force_auto_center()

  -- gui state
  gui_data.state = "search"
  gui_data.category = category
  player.opened = gui_data.search_textfield
  gui_data.search_textfield.focus()
  if options.query then
    gui_data.search_textfield.text = options.query
  end

  -- add to global
  player_table.gui.search = gui_data

  -- populate initial results
  gui.handlers.search.search_textfield.on_gui_text_changed{player_index=player.index, text=options.query or "", selected_index=options.selected_index}

  -- set shortcut state
  player.set_shortcut_toggled("rb-toggle-search", true)
end

function search_gui.close(player, player_table)
  if player_table.flags.searching then
    search.cancel(player.index, player_table)
  end
  gui.update_filters("search", player.index, nil, "remove")
  player_table.gui.search.window.destroy()
  player_table.gui.search = nil
  player.set_shortcut_toggled("rb-toggle-search", false)
end

function search_gui.toggle(player, player_table, options)
  local search_window = player.gui.screen.rb_search_window
  if search_window then
    search_gui.close(player, player_table)
  else
    -- check if we actually CAN open the GUI
    if player_table.flags.can_open_gui then
      search_gui.open(player, player_table, options)
    else
      -- set flag and tell the player that they cannot open it
      player_table.flags.tried_to_open_gui = true
      player.print{"rb-message.translation-not-finished"}
    end
  end
end

function search_gui.confirm_category(e)
  e.element = global.players[e.player_index].gui.search.search_textfield
  gui.handlers.search.search_textfield.on_gui_click(e)
end

function search_gui.confirm_result(e)
  e.element = global.players[e.player_index].gui.search.results_listbox
  e.keyboard_confirm = true
  gui.handlers.search.results_listbox.on_gui_selection_state_changed(e)
end

function search_gui.cycle_category(player, player_table)
  local gui_data = player_table.gui.search
  local next_category_index = math.max((constants.category_to_index[gui_data.category] + 1) % (constants.num_categories + 1), 1)
  local next_category = constants.category_by_index[next_category_index]
  gui.handlers.search.category_dropdown.on_gui_selection_state_changed({player_index=player.index, element=gui_data.category_dropdown}, next_category)
  gui_data.category_dropdown.selected_index = next_category_index
  gui_data.category_dropdown.focus()
end

return search_gui