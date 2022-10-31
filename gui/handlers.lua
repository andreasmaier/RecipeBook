local libgui = require("__flib__.gui")

local handlers = {}

--- @param self Gui
function handlers.close_button(self)
  self:hide()
end

--- @param e on_gui_checked_state_changed
function handlers.collapse_list_box(_, e)
  local state = e.element.state
  e.element.parent.parent.list_frame.style.height = state and 1 or 0
  -- TODO: Keep track of collapsed states
end

--- @param self Gui
--- @param e on_gui_click
function handlers.filter_group_button(self, e)
  if e.element.style.name ~= "rb_disabled_filter_group_button_tab" then
    self:select_filter_group(e.element.name)
  end
end

--- @param self Gui
function handlers.overhead_button(self)
  self:toggle()
end

--- @param self Gui
function handlers.pin_button(self)
  self:toggle_pinned()
end

--- @param self Gui
--- @param e on_gui_click
function handlers.prototype_button(self, e)
  local tags = libgui.get_tags(e.element)
  if tags.prototype then
    self:show_page(tags.prototype)
  end
end

--- @param self Gui
function handlers.search_button(self)
  self:toggle_search()
end

--- @param self Gui
--- @param e on_gui_text_changed
function handlers.search_textfield(self, e)
  -- TODO: Fuzzy search
  self.state.search_query = e.element.text
  self:update_filter_panel()
end

--- @param self Gui
--- @param e on_gui_click
function handlers.show_hidden_button(self, e)
  self.state.show_hidden = not self.state.show_hidden
  if self.state.show_hidden then
    e.element.style = "flib_selected_frame_action_button"
    e.element.sprite = "rb_show_hidden_black"
  else
    e.element.style = "frame_action_button"
    e.element.sprite = "rb_show_hidden_white"
  end
  self:update_filter_panel()
end

--- @param self Gui
--- @param e on_gui_click
function handlers.show_unresearched_button(self, e)
  self.state.show_unresearched = not self.state.show_unresearched
  if self.state.show_unresearched then
    e.element.style = "flib_selected_frame_action_button"
    e.element.sprite = "rb_show_unresearched_black"
  else
    e.element.style = "frame_action_button"
    e.element.sprite = "rb_show_unresearched_white"
  end
  self:update_filter_panel()
end

--- @param self Gui
--- @param e on_gui_click
function handlers.titlebar_flow(self, e)
  if e.button == defines.mouse_button_type.middle then
    self.refs.window.force_auto_center()
  end
end

--- @param self Gui
function handlers.window_closed(self)
  if not self.state.pinned then
    if self.state.search_open then
      self:toggle_search()
      self.player.opened = self.refs.window
    else
      self:hide()
    end
  end
end

return handlers
