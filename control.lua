require "defines"
require "config"

MOD_NAME = "RoboportLogistics"
local surface = nil

script.on_init(function()
	script.on_event(defines.events.on_tick, on_tick_after_load)
end)

script.on_load(function()
	script.on_event(defines.events.on_tick, on_tick_after_load)
end)

script.on_configuration_changed(function(data)
	if data.mod_changes[MOD_NAME] and data.mod_changes[MOD_NAME].new_version ~= data.mod_changes[MOD_NAME].old_version then
		print("Resetting RoboportLogistics due to new mod version.")
		
		reset_mod()
	end
	
	script.on_configuration_changed(nil)
end)


function insert_inventory(container, index, detected_table)
	for k,v in pairs(container.get_inventory(index).get_contents()) do
		add_detected_items(detected_table, k, v)
	end
end

function add_detected_items(detected_table, itemName, itemCount)
	local existing = detected_table[itemName]
	if existing == nil then 
		detected_table[itemName] = itemCount 
	else
		detected_table[itemName] = existing + itemCount
	end
end

function on_tick(event)
	if event.tick % config.tick_interval == config.tick_interval - 1 then
		local updated_count = 0
		local total_count = 0
		
		for _, data in pairs(global.roboport_data) do
			if data.inserter_count > 0 and isValid(data.roboport) then
				local inv_items = {}
				local bots = {}
				local parameters = {}
				local i = 1

				--add the roboports inventories 
				insert_inventory(data.roboport, 1, inv_items)
				insert_inventory(data.roboport, 2, inv_items)
				
				for k,v in pairs(inv_items) do
					parameters[i] = {signal = {type = "item", name = k}, count = v, index = i}
					i = i + 1
				end
				
				--add robot counts for this network
				if data.network == nil or data.force ~= data.roboport.force then
					update_data_network(data)
				end

				if data.network ~= nil then
					parameters[i] = {signal = {type = "virtual", name = "home-lrobots"}, count = data.network.available_logistic_robots, index = i}
					i = i + 1
					parameters[i] = {signal = {type = "virtual", name = "home-crobots"}, count = data.network.available_construction_robots, index = i}
					i = i + 1
					parameters[i] = {signal = {type = "virtual", name = "all-lrobots"}, count = data.network.all_logistic_robots, index = i}
					i = i + 1
					parameters[i] = {signal = {type = "virtual", name = "all-crobots"}, count = data.network.all_construction_robots, index = i}
					i = i + 1
				end

				data.proxy.set_circuit_condition(1, {parameters = parameters})
				
				updated_count = updated_count + 1
			end
			
			total_count = total_count + 1
		end
		
		--print("Updated " .. updated_count .. " of " .. total_count .. " proxies")
	end
end

function on_tick_after_load(event)	
	--set the surface variable, used for pretty much all the things
	surface = game.get_surface(1)
	
	--first run?
	if global.roboport_data == nil then
		global.roboport_data = {}
	end
	
	--TODO: PUT THIS IN A MIGRATION!
	if false then --this is really only for dev TODO: Disable it
		reset_mod()
	end
	
	--create new proxies if needed
	for c in surface.get_chunks() do
		for key, roboport in pairs(surface.find_entities_filtered({area={{c.x * 32, c.y * 32}, {c.x * 32 + 32, c.y * 32 + 32}}, name="roboport"})) do
			create_proxy(roboport)
		end
	end
	
	on_tick(event)
	script.on_event(defines.events.on_tick, on_tick)
end

function create_proxy(roboport)
	local data = get_roboport_data(roboport)
	
	if data == nil then
		local pos = roboport.position
		
		local proxy = surface.create_entity{name = "roboport-output-proxy", position = {pos.x, pos.y}, force = roboport.force}
		proxy.energy = 1
		proxy.destructible = false
		proxy.operable = false
		
		local data = {
			proxy = proxy, 
			roboport = roboport,
			connected_inserters = {},
			inserter_count = 0,
			force = nil,
			network = nil
		}
		
		local inserters = surface.find_entities_filtered({area={{pos.x - 3, pos.y - 3}, {pos.x + 3, pos.y + 3}}, name="smart-inserter"})
		local connected = 0
		for key, inserter in pairs(inserters) do
			if inserter.direction == get_direction_of_entity(roboport, inserter) then
				add_connected_inserter(data, inserter)
			end
		end
		
		update_data_network(data)
		cache_roboport_data(roboport, data)
	end
end

function connect_inserter(inserter)
	local pos = inserter.position

	local roboports = surface.find_entities_filtered({area={{pos.x - 1.5, pos.y - 1.5}, {pos.x + 1.5, pos.y + 1.5}}, name="roboport"})
	for _, roboport in pairs(roboports) do
		local data = get_roboport_data(roboport)
	
		if inserter.direction == get_direction_of_entity(roboport, inserter) then
			add_connected_inserter(data, inserter)
		else
			remove_connected_inserter(data, inserter)
		end
	end
end

function remove_inserter(inserter)
	--print("remove_inserter")

	local pos = inserter.position

	local roboports = surface.find_entities_filtered({area={{pos.x - 1.5, pos.y - 1.5}, {pos.x + 1.5, pos.y + 1.5}}, name="roboport"})
	for _, roboport in pairs(roboports) do
		local data = get_roboport_data(roboport)
	
		remove_connected_inserter(data, inserter)
	end
end

function destroy_proxy(roboport)
	--print("destroy_proxy")
	local proxy = get_roboport_data_and_remove(roboport)
	
	if proxy ~= nil then
		proxy.proxy.destroy()
	end
end

function entity_to_pos_str(entity)
	return entity.position.x..'_'..entity.position.y
end

function cache_roboport_data(roboport, data)
	global.roboport_data[entity_to_pos_str(roboport)] = data
end

function get_roboport_data(roboport)
	return global.roboport_data[entity_to_pos_str(roboport)]
end

function update_data_network(data)
	data.force = data.roboport.force
	data.network = data.roboport.force.find_logistic_network_by_position(data.roboport.position, data.roboport.surface)
end

function get_roboport_data_and_remove(roboport)
	local id = entity_to_pos_str(roboport)
	local data = global.roboport_data[id]
	
	global.roboport_data[id] = nil
	
	return data
end

function add_connected_inserter(data, inserter)
	data.proxy.connect_neighbour{wire=config.wire_color, target_entity=inserter, source_circuit_id=1}
			
	data.connected_inserters[entity_to_pos_str(inserter)] = inserter
	data.inserter_count = data.inserter_count + 1
end

function remove_connected_inserter(data, inserter)
	--print("remove_connected_inserter")

	local id = entity_to_pos_str(inserter)
	
	if data.connected_inserters[id] then
		data.proxy.disconnect_neighbour{wire=config.wire_color, target_entity=inserter, source_circuit_id=1}
			
		data.connected_inserters[id] = nil
		data.inserter_count = data.inserter_count - 1
	end
end

function on_entity_build(entity)
	if entity.name == 'roboport' then
		create_proxy(entity)
	elseif entity.name == 'smart-inserter' then
		connect_inserter(entity)
	end
end

function on_entity_mined(event)
	if event.entity.name == 'roboport' then
		destroy_proxy(event.entity)
		event.entity.destroy()
	elseif event.entity.name == 'smart-inserter' then
		remove_inserter(event.entity)
	end
end

function reset_mod()
	local count = 1
	local surface = game.get_surface(1)
	--remove all existing proxies
	for c in surface.get_chunks() do
		for key, proxy in pairs(surface.find_entities_filtered({area={{c.x * 32, c.y * 32}, {c.x * 32 + 32, c.y * 32 + 32}}, name="roboport-output-proxy"})) do
			proxy.destroy()

			count = count + 1
		end
	end
	
	global.roboport_data = {}
end

script.on_event(defines.events.on_built_entity, function(event) on_entity_build(event.created_entity) end)
script.on_event(defines.events.on_robot_built_entity, function(event) on_entity_build(event.created_entity) end)
script.on_event(defines.events.on_player_rotated_entity, function(event) on_entity_build(event.entity) end)
script.on_event(defines.events.on_preplayer_mined_item, on_entity_mined)
script.on_event(defines.events.on_robot_pre_mined, on_entity_mined)

--returns the defines.direction of entity b relative to entity a
--returns -1 b's position is inside of a
--does not take b's selection_box into account.
--I have no idea if the directions are actually correct, but testing for my use, it worked great
function get_direction_of_entity(a, b)
	local posa = a.position
	local posb = b.position
	local sel = game.entity_prototypes[a.name].selection_box
	
	local top = posa.y + sel.left_top.y
	local left = posa.x + sel.left_top.x
	local bottom = posa.y + sel.right_bottom.y
	local right = posa.x + sel.right_bottom.x

	if posb.y < top then --above a
		if posb.x < left then --to the left
			return defines.direction.northeast
		elseif posb.x > right then --to right
			return defines.direction.northwest
		else --in the middle
			return defines.direction.north
		end
	elseif posb.y > bottom then --below a
		if posb.x < left then --to the left
			return defines.direction.southeast
		elseif posb.x > right then --to right
			return defines.direction.southwest
		else --in the middle
			return defines.direction.south
		end
		
	elseif posb.x < left then --to the right 
		return defines.direction.west
		
	elseif posb.x > right then
		return defines.direction.east
	else
		return -1 
	end
end

--turn direction constant into it's string name
local direction_strings = {}
for d, i in pairs(defines.direction) do
	direction_strings[i] = d
end
function directionToString(direction)
	return direction_strings[direction]
end

function isValid(entity)
	return(entity ~= nil and entity.valid)
end

function print(msg)
	for _, player in ipairs(game.players) do
		player.print(msg)
	end
end