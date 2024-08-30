local UPDATE_RATE = 3     -- ticks
local UPDATE_BUCKETS = 20 -- 20 buckets * 3 ticks per bucket update = 1 second crafting time

local BIT_ORDER = {
    ['h2o-up-coral'] = 1,
    ['h2o-down-coral'] = 2,
    ['h2o-top-coral'] = 4,
    ['h2o-bottom-coral'] = 8,
    ['h2o-strange-coral'] = 16,
    ['h2o-charm-coral'] = 32,
}
local TOTAL_BITS = table_size(BIT_ORDER)

local function calculate_matching_bits(secret, experiment)
    local matching_bits = 0
    for _, bit_value in pairs(BIT_ORDER) do
        if bit32.band(bit_value, secret) == bit32.band(bit_value, experiment) then
            matching_bits = matching_bits + 1
        end
    end
    return matching_bits
end

h2o.on_event('on_init', function()
    global.quantum_computers = global.quantum_computers or {}

    if not global.quantum_computers_by_tick then
        global.quantum_computers_by_tick = {}
        for i = 1, UPDATE_BUCKETS do
            global.quantum_computers_by_tick[i] = {}
        end
    end
end)

local function generate_new_secret()
    return math.random(1, 63)
end

local function get_smallest_bucket_index()
    local smallest_bucket_index = 1
    local smallest_bucket_size = math.huge
    for i, bucket in pairs(global.quantum_computers_by_tick) do
        if #bucket < smallest_bucket_size then
            smallest_bucket_size = #bucket
            smallest_bucket_index = i
        end
    end
    return smallest_bucket_index
end

h2o.on_event('on_built', function(event)
    local entity = event.entity or event.created_entity
    if not entity.valid then return end
    if entity.name ~= 'h2o-quantum-computer' then return end

    entity.active = false
    entity.operable = false

    local quantum_computer_data = {
        entity = entity,
        unit_number = entity.unit_number,
        previous_experiment = nil,
        secret = generate_new_secret()
    }

    global.quantum_computers[entity.unit_number] = quantum_computer_data
    local bucket_index = get_smallest_bucket_index()
    table.insert(global.quantum_computers_by_tick[bucket_index], quantum_computer_data)
end)

local HEART_OF_THE_SEA = 'h2o-heart-of-the-sea'
local LIMESTONE = 'limestone'
local DOWN_CORAL = 'h2o-down-coral'
local UP_CORAL = 'h2o-up-coral'

local function do_experiement(quantum_computer_data, current_experiment)
    local secret = quantum_computer_data.secret
    local current_matching_bits = calculate_matching_bits(secret, current_experiment)

    if current_matching_bits == TOTAL_BITS then
        quantum_computer_data.previous_experiment = nil
        quantum_computer_data.previous_matching_bits = nil
        quantum_computer_data.secret = generate_new_secret()
        return HEART_OF_THE_SEA
    end

    local previous_experiment = quantum_computer_data.previous_experiment
    local previous_matching_bits = quantum_computer_data.previous_matching_bits
    quantum_computer_data.previous_experiment = current_experiment
    quantum_computer_data.previous_matching_bits = current_matching_bits

    if not previous_experiment then
        return LIMESTONE
    end

    if not previous_matching_bits then
        previous_matching_bits = calculate_matching_bits(secret, previous_experiment)
    end

    if current_matching_bits > previous_matching_bits then
        return UP_CORAL
    elseif current_matching_bits < previous_matching_bits then
        return DOWN_CORAL
    else
        return LIMESTONE
    end
end

--- invariant: quantum_computer_data.entity.valid
local function update_quantum_computer(quantum_computer_data)
    local entity = quantum_computer_data.entity

    local fluidbox = entity.fluidbox[1]
    if not fluidbox then return end
    if fluidbox.amount < 99.999 then return end

    local output = entity.get_inventory(defines.inventory.assembling_machine_output)
    if not output.is_empty() then return end
    local input = entity.get_inventory(defines.inventory.assembling_machine_input)
    if input.is_empty() then return end

    local contents = input.get_contents()
    local experiment = 0
    for coral, bit_value in pairs(BIT_ORDER) do
        if contents[coral] then
            experiment = experiment + bit_value
        end
    end

    local result = do_experiement(quantum_computer_data, experiment)
    local flow = entity.force.item_production_statistics
    output.insert {name = result, count = 1}
    flow.on_flow(result, 1)

    for item in pairs(contents) do
        input.remove {name = item, count = 1}
        flow.on_flow(item, -1)
    end
end

h2o.on_nth_tick(UPDATE_RATE, function()
    local bucket_index = math.floor(game.tick / UPDATE_RATE) % UPDATE_BUCKETS + 1
    local bucket = global.quantum_computers_by_tick[bucket_index]

    for i, quantum_computer_data in pairs(bucket) do
        local entity = quantum_computer_data.entity
        if not entity.valid then
            global.quantum_computers[quantum_computer_data.unit_number] = nil
            table.remove(bucket, i)
            break
        end
        update_quantum_computer(quantum_computer_data)
    end
end)
