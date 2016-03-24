data:extend({
{
	type = "item-subgroup",
	name = "virtual-signal-sensor",
	group = "signals",
	order = "z"
},
{
    type = "virtual-signal",
	name = "home-lrobots",
	icon = "__RoboportLogistics__/graphics/lbot-rdy.png",
	subgroup = "virtual-signal-sensor",
	order = "z[sensor-a]",
},
{
    type = "virtual-signal",
	name = "home-crobots",
	icon = "__RoboportLogistics__/graphics/cbot-rdy.png",
	subgroup = "virtual-signal-sensor",
	order = "z[sensor-a]",
},
{
    type = "virtual-signal",
	name = "all-lrobots",
	icon = "__RoboportLogistics__/graphics/lbot-all.png",
	subgroup = "virtual-signal-sensor",
	order = "z[sensor-a]",
},
{
    type = "virtual-signal",
	name = "all-crobots",
	icon = "__RoboportLogistics__/graphics/cbot-all.png",
	subgroup = "virtual-signal-sensor",
	order = "z[sensor-a]",
},

  {
    type = "constant-combinator", --decider-combinator
    name = "roboport-output-proxy",
	icon = "__base__/graphics/entity/smart-chest/smart-chest.png",
	--flags = {"placeable-neutral", "player-creation"},
    minable = {hardness = 0.2, mining_time = 0.5, result = "constant-combinator"},
	selectable_in_game = false,
	--collision_mask = {"ghost-layer"},

	max_health = 1,
	--subgroup = "grass",
    --order="z",
	
	collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},

    item_slot_count = 20, -- must be at least the total amount of signal-able items in the current instance, to be safe.

    sprite =
    {
      filename = "__base__/graphics/entity/smart-chest/smart-chest.png",
      priority = "extra-high",
      width = 0,
      height = 0,
      shift = {0,0}
    },

    circuit_wire_connection_point =
    {
      shadow =
      {
        red = {-1.335625, -1.278125}, --TODO: Adjust
        green = {0, 0},
      },
      wire =
      {
        red = {-1.355625, -1.288125},
        green = {0, 0},
      }
    },
    circuit_wire_max_distance = 7.5
  },
}
)