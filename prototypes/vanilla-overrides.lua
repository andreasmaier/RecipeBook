-- recipe_book.set_hidden(data.raw["item"]["electric-energy-interface"], true)
-- recipe_book.set_hidden(data.raw["electric-energy-interface"]["electric-energy-interface"], true)

-- recipe_book.set_group_with(data.raw["fish"]["fish"], data.raw["capsule"]["raw-fish"])
-- recipe_book.set_group_with(data.raw["straight-rail"]["straight-rail"], data.raw["rail-planner"]["rail"])
-- recipe_book.set_group_with(data.raw["tile"]["stone-path"], data.raw["item"]["stone-brick"])

-- recipe_book.set_hidden(data.raw["item"]["rocket-part"], false)

-- for _, recipe in pairs(data.raw["recipe"]) do
--   if string.match(recipe.name, "^empty%-.*%-barrel$") then
--     recipe_book.set_unlocks_results(recipe, false)
--   end
-- end
