local flib_dictionary = require("__flib__.dictionary")
local flib_migration = require("__flib__.migration")

local database = require("scripts.database")
local gui = require("scripts.gui")
local researched = require("scripts.researched")

local by_version = {
  ["4.0.0"] = function()
    global = {}

    flib_dictionary.on_init()

    database.on_init()
    gui.on_init()
    researched.on_init()
  end,
}

local migrations = {}

--- @param e ConfigurationChangedData
function migrations.on_configuration_changed(e)
  flib_migration.on_config_changed(e, by_version)
end

return migrations
