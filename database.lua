local dictionary = require("__flib__.dictionary")
local table = require("__flib__.table")

local util = require("__RecipeBook__.util")

-- DESIGN GOALS:
-- Find a balance between caching information and generating it on the fly
-- Reduce complexity as much as possible
-- Don't rely on translated strings at all
-- Type annotations!!!

-- TODO: Use data-stage properties instead of hardcoding
local excluded_categories = {
  ["ee-testing-tool"] = true,
  ["big-turbine"] = true,
  ["condenser-turbine"] = true,
  ["delivery-cannon"] = true,
  ["spaceship-antimatter-engine"] = true,
  ["spaceship-ion-engine"] = true,
  ["spaceship-rocket-engine"] = true,
}

local database = {}

--- @param a GenericPrototype
--- @param b GenericPrototype
local function compare_icons(a, b)
  if game.active_mods.base == "1.1.71" then
    return table.deep_compare(a.icons, b.icons)
  else
    -- TEMPORARY:
    return a.name == b.name
  end
end

--- @param entry PrototypeEntry
--- @param force_index uint
local function add_researched(entry, force_index)
  if entry.researched then
    entry.researched[force_index] = true
  else
    entry.researched = { [force_index] = true }
  end
end

--- @class SubgroupData
--- @field members GenericPrototype[]
--- @field parent_name string

function database.build_groups()
  log("Generating database")
  local profiler = game.create_profiler()

  local search_strings = dictionary.new("search")

  --- Each top-level prototype sorted into groups and subgroups for the search_interface
  --- @type table<string, table<string, GenericPrototype>>
  log("Search tree")
  local search_tree = {}
  global.search_tree = search_tree
  for group_name, group_prototype in pairs(game.item_group_prototypes) do
    local subgroups = {}
    for _, subgroup_prototype in pairs(group_prototype.subgroups) do
      subgroups[subgroup_prototype.name] = {}
    end
    search_tree[group_name] = subgroups
  end
  --- Indexable table of objects
  --- @type table<string, PrototypeEntry>
  local db = {}
  global.database = db

  --- @param prototype GenericPrototype
  --- @param group_with GenericPrototype?
  --- @return PrototypeEntry?
  local function add_prototype(prototype, group_with)
    local path, type = util.get_path(prototype)
    local entry = db[path]
    if not entry then
      if group_with then
        local parent_path = util.get_path(group_with)
        local parent_entry = db[parent_path]
        if parent_entry and not parent_entry[type] and compare_icons(prototype, group_with) then
          parent_entry[type] = prototype -- Add this prototype to the parent
          db[path] = parent_entry -- Associate this prototype with the group's data
          return entry
        end
      end

      -- Add to database
      db[path] = { base = prototype, base_path = path, [type] = prototype }
      -- Add to filter panel and search dictionary
      local subgroup = search_tree[prototype.group.name][prototype.subgroup.name]
      local order = prototype.order
      -- TODO: Binary search
      for i, other_entry in pairs(subgroup) do
        if order <= db[other_entry].base.order then
          table.insert(subgroup, i, path)
          return
        end
      end
      table.insert(subgroup, path)
      search_strings:add(util.prototype_type[prototype.object_name] .. "/" .. prototype.name, prototype.localised_name)

      return db[path]
    end
  end

  -- Recipes determine what is actually attainable in the game
  -- All other objects will only be added if they are related to a recipe
  log("Recipes")
  --- @type table<string, GenericPrototype>
  local materials_to_add = {}
  for _, recipe_prototype in pairs(game.recipe_prototypes) do
    if not excluded_categories[recipe_prototype.category] then
      add_prototype(recipe_prototype)
      -- Group with the main product if the icons match
      local main_product = recipe_prototype.main_product
      if not main_product then
        local products = recipe_prototype.products
        if #products == 1 then
          main_product = products[1]
        end
      end
      if main_product then
        local product_prototype = util.get_prototype(main_product)
        add_prototype(product_prototype, recipe_prototype)
      end
      -- Mark all ingredients and products for adding in the next step
      for _, ingredient in pairs(recipe_prototype.ingredients) do
        materials_to_add[ingredient.type .. "/" .. ingredient.name] = util.get_prototype(ingredient)
      end
      for _, product in pairs(recipe_prototype.products) do
        materials_to_add[product.type .. "/" .. product.name] = util.get_prototype(product)
      end
    end
  end

  log("Materials")
  for _, prototype in pairs(materials_to_add) do
    add_prototype(prototype) -- If a material was grouped with a recipe, this will do nothing
    if prototype.object_name == "LuaItemPrototype" then
      local place_result = prototype.place_result
      if place_result then
        add_prototype(place_result, prototype)
      end
      for _, product in pairs(prototype.rocket_launch_products) do
        add_prototype(util.get_prototype(product))
      end
    end
  end

  log("Resources")
  for _, prototype in pairs(game.get_filtered_entity_prototypes({ { filter = "type", type = "resource" } })) do
    local mineable = prototype.mineable_properties
    if mineable.minable then
      local products = mineable.products
      if products and #products > 0 then
        local should_add, grouped_material
        for _, product in pairs(mineable.products) do
          local product_prototype = util.get_prototype(product)
          local product_path = util.get_path(product_prototype)
          -- Only add resources whose products have an entry (and therefore, a recipe)
          if db[product_path] then
            should_add = true
            if compare_icons(prototype, product_prototype) then
              grouped_material = product_prototype
              break
            end
          end
        end
        if should_add then
          add_prototype(prototype, grouped_material)
        end
      end
    end
  end

  log("Technologies and research status")
  for name in pairs(game.technology_prototypes) do
    local path = "technology/" .. name
    db[path] = {}
  end
  for _, force in pairs(game.forces) do
    database.refresh_researched(force)
  end

  log("Search tree cleanup")
  for group_name, group in pairs(search_tree) do
    local size = 0
    for subgroup_name, subgroup in pairs(group) do
      if #subgroup == 0 then
        group[subgroup_name] = nil
      else
        size = size + 1
      end
    end
    if size == 0 then
      search_tree[group_name] = nil
    end
  end

  profiler.stop()
  log({ "", "Database generated, ", profiler })
end

--- @param entity LuaEntityPrototype
--- @param force_index uint
function database.on_entity_unlocked(entity, force_index)
  local db = global.database
  local entry = db["entity/" .. entity.name]
  if entry then
    add_researched(entry, force_index)
  end
  if entity.type == "mining-drill" then
    -- Resources
    local categories = entity.resource_categories --[[@as table<string, _>]]
    local fluidbox = entity.fluidbox_prototypes[1]
    local fluidbox_filter = fluidbox and fluidbox.filter or nil
    for resource_name, resource in
      pairs(game.get_filtered_entity_prototypes({ { filter = "type", type = "resource" } }))
    do
      local mineable = resource.mineable_properties
      if mineable.products and categories[resource.resource_category] then
        -- Check fluid compatibility
        local required_fluid = mineable.required_fluid
        if not required_fluid or (fluidbox and (not fluidbox_filter or fluidbox_filter == required_fluid)) then
          -- Add resource entry
          local resource_entry = db["entity/" .. resource_name]
          if resource_entry then
            add_researched(resource_entry, force_index)
          end
          for _, product in pairs(mineable.products) do
            database.on_product_unlocked(product, force_index)
          end
        end
      end
    end
  elseif entity.type == "offshore-pump" then
    -- Pumped fluid
    local fluid = entity.fluid
    if fluid then
      local fluid_entry = db["fluid/" .. fluid.name]
      if fluid_entry then
        add_researched(fluid_entry, force_index)
      end
    end
  elseif entity.type == "boiler" then
    -- Produced fluid
    for _, fluidbox in pairs(entity.fluidbox_prototypes) do
      if fluidbox.production_type == "output" and fluidbox.filter then
        database.on_product_unlocked({ type = "fluid", name = fluidbox.filter.name }, force_index)
      end
    end
  end
end

--- @param product Product
--- @param force_index uint
function database.on_product_unlocked(product, force_index)
  local db = global.database
  local entry = db[product.type .. "/" .. product.name]
  if not entry then
    return
  end
  add_researched(entry, force_index)
  local prototype
  if product.type == "fluid" then
    prototype = game.fluid_prototypes[product.name]
  else
    prototype = game.item_prototypes[product.name]
  end
  if product.type == "item" then
    -- Rocket launch products
    local rocket_launch_products = prototype.rocket_launch_products
    if rocket_launch_products then
      for _, product in pairs(rocket_launch_products) do
        database.on_product_unlocked(product, force_index)
      end
    end
    -- Burnt results
    local burnt_result = prototype.burnt_result
    if burnt_result then
      database.on_product_unlocked({ type = "item", name = burnt_result.name }, force_index)
    end
    -- Place result
    local place_result = prototype.place_result
    if place_result then
      database.on_entity_unlocked(place_result, force_index)
    end
  end
end

--- @param recipe LuaRecipe
--- @param force_index uint
function database.on_recipe_unlocked(recipe, force_index)
  local db = global.database
  local entry = db["recipe/" .. recipe.name]
  if not entry then
    return
  end
  add_researched(entry, force_index)
  if recipe.prototype.unlock_results then
    for _, product in pairs(recipe.products) do
      database.on_product_unlocked(product, force_index)
    end
  end
end

--- @param technology LuaTechnology
--- @param force_index uint
function database.on_technology_researched(technology, force_index)
  local technology_name = technology.name
  local db = global.database
  local technology_path = "technology/" .. technology_name
  if not db[technology_path] then
    db[technology_path] = { researched = {} }
  end
  add_researched(db[technology_path], force_index)
  for _, effect in pairs(technology.effects) do
    if effect.type == "unlock-recipe" then
      local recipe = technology.force.recipes[effect.recipe]
      database.on_recipe_unlocked(recipe, force_index)
    end
  end
end

--- @param force LuaForce
function database.refresh_researched(force)
  local force_index = force.index
  -- Gather-able items
  for _, entity in
    pairs(game.get_filtered_entity_prototypes({
      { filter = "type", type = "simple-entity" },
      { filter = "type", type = "tree" },
    }))
  do
    if entity.type == "tree" or entity.count_as_rock_for_filtered_deconstruction then
      local mineable = entity.mineable_properties
      if mineable.minable and mineable.products then
        for _, product in pairs(mineable.products) do
          database.on_product_unlocked(product, force_index)
        end
      end
    end
  end
  -- Technologies
  for _, technology in pairs(force.technologies) do
    if technology.researched then
      database.on_technology_researched(technology, force_index)
    end
  end
  -- Recipes (some may be enabled without technologies)
  local db = global.database
  for _, recipe in pairs(force.recipes) do
    -- Some recipes will be enabled from the start, but will only be craftable in machines
    if recipe.enabled and not (recipe.prototype.enabled and recipe.prototype.hidden_from_player_crafting) then
      local entry = db["recipe/" .. recipe.name]
      if entry and not (entry.researched or {})[force_index] then
        add_researched(entry, force_index)
        database.on_recipe_unlocked(recipe, force_index)
      end
    end
  end
end

--- @param path string
--- @return string? base_path
function database.get_base_path(path)
  local entry = global.database[path]
  if entry then
    local base_path = util.get_path(entry.base)
    return base_path
  end
end

--- @param entry PrototypeEntry
--- @return table
function database.get_properties(entry, force_index)
  local base = entry.base
  local properties = {
    hidden = util.is_hidden(base),
    researched = entry.researched and entry.researched[force_index] or false,
  }

  local recipe = entry.recipe
  if recipe then
    properties.ingredients = recipe.ingredients
    properties.products = recipe.products
  end

  return properties
end

--- @param obj GenericObject
--- @return boolean
function database.is_researched(obj, force_index)
  local entry = global.database[obj.type .. "/" .. obj.name]
  if entry and entry.researched and entry.researched[force_index] then
    return true
  end
  return false
end

--- @param obj GenericObject
--- @return boolean
function database.is_hidden(obj)
  local entry = global.database[obj.type .. "/" .. obj.name]
  if entry and util.is_hidden(entry.base) then
    return true
  end
  return false
end

--- @param obj GenericObject
--- @return PrototypeEntry?
function database.get_entry(obj)
  return global.database[obj.type .. "/" .. obj.name]
end

return database
