require "defines"
require "config"

--DONT EDIT THIS IF YOU DON'T KNOW WHAT YOU'RE DOING
local surface = nil

script.on_init(function()
	script.on_event(defines.events.on_tick, onTickAfterLoad)
end)

script.on_load(function()
	script.on_event(defines.events.on_tick, onTickAfterLoad)
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

function onTickMain(event)
	if event.tick % 10 == 3 then
		for _, p in pairs(global.proxies) do
			local inv_items = {}
			local parameters = {}
			local i = 1
			
			insert_inventory(p.roboport, 1, inv_items)
			insert_inventory(p.roboport, 2, inv_items)
			
			for k,v in pairs(inv_items) do
				parameters[i] = {signal = {type = "item", name = k}, count = v, index = i}
				i = i + 1
			end
		
			p.proxy.set_circuit_condition(1, {parameters = parameters})
		end
	end
end

function onTickAfterLoad(event)	
	--set the surface variable, used for pretty much all the things
	surface = game.get_surface(1)
	
	--first run?
	if global.proxies == nil then
		global.proxies = {}
	end
	
	if false then --this is really only for dev TODO: Disable it
		local count = 1
		--remove all existing proxies
		for c in surface.get_chunks() do
			for key, proxy in pairs(surface.find_entities_filtered({area={{c.x * 32, c.y * 32}, {c.x * 32 + 32, c.y * 32 + 32}}, name="roboport-output-proxy"})) do
				proxy.destroy()

				count = count + 1
			end
		end
		
		global.proxies = {}
	end
	
	--create new proxies if needed
	for c in surface.get_chunks() do
		for key, roboport in pairs(surface.find_entities_filtered({area={{c.x * 32, c.y * 32}, {c.x * 32 + 32, c.y * 32 + 32}}, name="roboport"})) do
			createProxy(roboport)
		end
	end
	
	onTickMain(event)
	script.on_event(defines.events.on_tick, onTickMain)
end

function createProxy(roboport)
	local proxy = getProxyByEntity(roboport)
	
	if proxy == nil then
		local pos = roboport.position
		local proxy = surface.create_entity{name = "roboport-output-proxy", position = {pos.x, pos.y}, force = roboport.force}
		
		proxy.energy = 1
		proxy.destructible = false
		proxy.operable = false
		
		local inserters = surface.find_entities_filtered({area={{pos.x - 3, pos.y - 3}, {pos.x + 3, pos.y + 3}}, name="smart-inserter"})
		for key, inserter in pairs(inserters) do
			if inserter.direction == getDirectionOfEntity(roboport, inserter) then
				proxy.connect_neighbour{wire=config.wire_color, target_entity=inserter, source_circuit_id=1}
			end
		end

		table.insert(global.proxies, {proxy=proxy, roboport=roboport})
	end
end

function connectInserter(inserter)
	local pos = inserter.position

	local proxies = surface.find_entities_filtered({area={{pos.x - 1.5, pos.y - 1.5}, {pos.x + 1.5, pos.y + 1.5}}, name="roboport-output-proxy"})
	for key, proxy in pairs(proxies) do
		if inserter.direction == getDirectionOfEntity(proxy, inserter) then
			proxy.connect_neighbour{wire=config.wire_color, target_entity=inserter, source_circuit_id=1}
		else
			proxy.disconnect_neighbour{wire=config.wire_color, target_entity=inserter, source_circuit_id=1}
		end
	end
end

function destroyProxy(roboport)
	local proxy = getProxyByEntityAndRemove(roboport)
	
	if proxy ~= nil then
		proxy.proxy.destroy()
	end
end

function getProxyByEntity(roboport)
	for _, p in pairs(global.proxies) do
		if p.roboport == roboport then
			return p
		end
	end
	
	return nil
end

function getProxyByEntityAndRemove(roboport)
	for i, p in pairs(global.proxies) do
		if p.roboport == roboport then
			return table.remove(global.proxies, i)
		end
	end
	
	return nil
end

function on_entity_build(entity)
	if entity.name == 'roboport' then
		createProxy(entity)
	elseif entity.name == 'smart-inserter' then
		connectInserter(entity)
	end
end

function on_entity_mined(event)
	if event.entity.name == 'roboport' then
		destroyProxy(event.entity)
	end
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
function getDirectionOfEntity(a, b)
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

function print(msg)
	for _, player in ipairs(game.players) do
		player.print(msg)
	end
end