local function transfer_equipment_grid(old_armor, new_armor)
    local old_armor_grid = old_armor.grid
    local new_armor_grid = new_armor.grid

    if not old_armor_grid then return end
    assert(new_armor_grid)

    for _, equipment in pairs(old_armor_grid.equipment) do
        local is_ghost = equipment.type == "equipment-ghost"
        new_armor_grid.put {
            name = is_ghost and equipment.ghost_name or equipment.name,
            position = equipment.position,
            quality = equipment.quality,
            ghost = is_ghost, -- vanilla bug: this just deletes the ghosts if true
            by_player = player,
        }
    end
end

local function transfer_armor_item(armor, target_armor_name)
    if not prototypes.item[target_armor_name] then return end
    local temp_inventory = game.create_inventory(1)
    local stack = temp_inventory[1]
    stack.set_stack {
        name = target_armor_name,
        count = 1,
        quality = armor.quality,
        health = armor.health,
        spoil_percent = armor.spoil_percent
    }

    transfer_equipment_grid(armor, stack)
    armor.set_stack(stack)
    temp_inventory.destroy()
end

local function update_armor(player)
    local armor_inventory
    if player.controller_type == defines.controllers.editor then
        armor_inventory = player.get_inventory(defines.inventory.editor_armor)
    else
        armor_inventory = player.get_inventory(defines.inventory.character_armor)
    end
    if not armor_inventory or armor_inventory.is_empty() then return end

    local armor = armor_inventory[1]
    if not armor.valid_for_read then return end
    
    local armor_name = armor.name
    local target_armor_name
    local physical_surface = player.physical_surface
    if maraxsis.MARAXSIS_SURFACES[physical_surface.name] then
        target_armor_name = armor_name .. "-maraxsis-swimming"
    else
        target_armor_name = armor_name:gsub("%-maraxsis%-swimming", "")
    end

    if armor_name == target_armor_name then return end

    transfer_armor_item(armor, target_armor_name)
end

maraxsis.on_event({
    defines.events.on_player_changed_surface,
    defines.events.on_player_respawned,
    defines.events.on_player_driving_changed_state,
    defines.events.on_player_armor_inventory_changed,
    defines.events.on_player_cheat_mode_enabled,
    defines.events.on_player_controller_changed,
}, function(event)
    local player = game.get_player(event.player_index)
    update_armor(player)
end)

maraxsis.on_nth_tick(537, function(event)
    for _, player in pairs(game.connected_players) do
        update_armor(player)
    end
end)

maraxsis.on_event(defines.events.on_player_cursor_stack_changed, function(event)
    local player = game.get_player(event.player_index)
    local cursor_stack = player.cursor_stack
    if not cursor_stack.valid_for_read then return end

    local cursor_stack_name = cursor_stack.name
    if not cursor_stack_name:find("-maraxsis-swimming", 1, true) then return end

    local target_stack_name = cursor_stack_name:gsub("%-maraxsis%-swimming", "")
    transfer_armor_item(cursor_stack, target_stack_name)
end)