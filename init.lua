--[[
	Standalone Fishing Mod
	An isolated, independent conversion of the Ethereal/Rootyjr fishing routine.
]]--

-- Global mod namespace initialization (replaces the old 'ethereal' global table)
standalone_fishing = {}

-- Safe translation domain fallback
local S = core.get_translator and core.get_translator("standalone_fishing") or function(str) return str end

-- Structural check variables for optional mods
local mod_bonemeal = core.get_modpath("bonemeal")
local mod_armor    = core.get_modpath("3d_armor")
local mod_mobs     = core.get_modpath("mobs")
local mod_farming  = core.get_modpath("farming")
local mod_vessels  = core.get_modpath("vessels")
local mod_flowers  = core.get_modpath("flowers")
local mod_fireflies = core.get_modpath("fireflies")
local mod_tnt       = core.get_modpath("tnt")
local mod_bucket    = core.get_modpath("bucket")

-- Safely bind local item strings based on engine dependencies
local string_item = mod_farming and "farming:string" or "default:grass_1"
local bottle_item = mod_vessels and "vessels:glass_bottle" or "default:glass"
local lily_item   = mod_flowers and "flowers:waterlily" or "default:papyrus"
local paper_item  = core.registered_items["default:paper"] and "default:paper" or "default:book"

-- Complete fish pool table (Maintained all entries, stripped Ethereal biomes to clear safe default drops)
local fish_items = {
	"standalone_fishing:fish_bluefin",
	"standalone_fishing:fish_blueram",
	"standalone_fishing:fish_catfish",
	"standalone_fishing:fish_plaice",
	"standalone_fishing:fish_salmon",
	"standalone_fishing:fish_clownfish",
	"standalone_fishing:fish_pike",
	"standalone_fishing:fish_flathead",
	"standalone_fishing:fish_pufferfish",
	"standalone_fishing:fish_cichlid",
	"standalone_fishing:fish_coy",
	"standalone_fishing:fish_tilapia",
	"standalone_fishing:fish_trevally",
	"standalone_fishing:fish_angler",
	"standalone_fishing:fish_jellyfish",
	"standalone_fishing:fish_seahorse",
	"standalone_fishing:fish_seahorse_green",
	"standalone_fishing:fish_seahorse_pink",
	"standalone_fishing:fish_seahorse_blue",
	"standalone_fishing:fish_seahorse_yellow",
	"standalone_fishing:fish_parrot",
	"standalone_fishing:fish_piranha",
	"standalone_fishing:fish_tuna",
	"standalone_fishing:fish_trout",
	"standalone_fishing:fish_cod",
	"standalone_fishing:fish_flounder",
	"standalone_fishing:fish_redsnapper",
	"standalone_fishing:fish_squid",
	"standalone_fishing:fish_shrimp",
	"standalone_fishing:fish_carp",
	"standalone_fishing:fish_tetra",
	"standalone_fishing:fish_mackerel"
}

-- Complete junk items table with fallbacks
local junk_items = {
	"default:stick",
	string_item,
	"default:papyrus",
	"dye:black",
	lily_item,
	paper_item,
	"flowers:mushroom_red",
	bottle_item,
	mod_bonemeal and "bonemeal:bone" or "default:stick",
	mod_armor and "3d_armor:boots_wood 6000" or "default:stick"
}

-- Complete bonus items table with fallbacks
local bonus_items = {
	mod_mobs and "mobs:nametag" or (mod_fireflies and "fireflies:bug_net" or "default:stick"),
	mod_mobs and "mobs:net" or "default:sapling",
	mod_fireflies and "fireflies:firefly_bottle" or bottle_item,
	mod_mobs and "mobs:saddle" or (mod_farming and "farming:cotton_wild" or "default:dry_shrub"),
	"default:book",
	mod_tnt and "tnt:tnt_stick" or "default:coal_lump",
	mod_bucket and "bucket:bucket_empty" or "default:iron_lump",
	"default:sword_steel 12000",
	"standalone_fishing:fishing_rod 9000"
}

local default_item = "default:dirt"
local random = math.random

-- RETAINED FUNCTION: Global item injection registration access point
function standalone_fishing.add_item(fish, junk, bonus)
	if fish and fish ~= "" then table.insert(fish_items, fish) end
	if junk and junk ~= "" then table.insert(junk_items, junk) end
	if bonus and bonus ~= "" then table.insert(bonus_items, bonus) end
end

-- RETAINED FUNCTION: Standalone dummy implementation for tracking eatables across mods
function standalone_fishing.add_eatable(item, hp)
	-- Hook footprint kept active to mimic Ethereal registration functions cleanly
end

-- Bubble particle pipeline
local function effect(pos)
	core.add_particle({
		pos = {
			x = pos.x + random() - 0.5,
			y = pos.y + 0.1,
			z = pos.z + random() - 0.5
		},
		velocity = {x = 0, y = 4, z = 0},
		acceleration = {x = 0, y = -5, z = 0},
		expirationtime = random() * 0.5,
		size = random(),
		collisiondetection = false,
		vertical = false,
		texture = "bubble.png",
		glow = 1
	})
end

-- Bobber entity engine implementation
local get_node = core.get_node

core.register_entity("standalone_fishing:bob_entity", {

	initial_properties = {
		textures = {"standalone_fishing_bob.png"},
		visual_size = {x = 0.5, y = 0.5},
		collisionbox = {-0.1, -0.1, -0.1, 0.1, 0.1, 0.1},
		physical = false,
		pointable = false,
		static_save = false,
		glow = 2
	},

	timer = 0,

	on_step = function(self, dtime)

		local pos = self.object:get_pos()
		local node = get_node(pos)
		local def = core.registered_nodes[node.name]

		-- Handle non-cast physical impacts
		if not self.cast then

			if (def and def.walkable) or node.name == "ignore" then
				self.object:remove()
				return
			end

			-- Liquid checking setup
			if def and def.liquidtype == "source"
			and core.get_item_group(node.name, "water") > 0 then

				local free_fall, blocker = core.line_of_sight(
						{x = pos.x, y = pos.y + 2, z = pos.z},
						{x = pos.x, y = pos.y    , z = pos.z})

				local player = self.fisher and core.get_player_by_name(self.fisher)
				local inv = player and player:get_inventory()
				local bait = 0

				-- Support checking for bait types
				if inv and inv:contains_item("main", "caverealms:glow_bait") then
					inv:remove_item("main", "caverealms:glow_bait")
					bait = 40
				elseif inv and inv:contains_item("main", "standalone_fishing:worm") then
					inv:remove_item("main", "standalone_fishing:worm")
					bait = 20
				end

				pos = {x = pos.x, y = blocker.y + 0.45, z = pos.z}

				self.object:set_acceleration({x = 0, y = 0, z = 0})
				self.object:set_velocity({x = 0, y = 0, z = 0})
				self.object:set_pos(pos)
				self.bait = bait
				self.cast = true

				effect(pos) ; effect(pos) ; effect(pos) ; effect(pos)
				core.sound_play("default_water_footstep", {pos = pos, gain = 0.1}, true)
			end

		else -- Already cast logic branch

			if self.fisher == nil or self.fisher == "" then
				self.object:remove()
				return
			end

			local player = core.get_player_by_name(self.fisher)
			if not player then
				self.object:remove()
				return
			end

			local wield = player:get_wielded_item()
			if not wield or wield:get_name() ~= "standalone_fishing:fishing_rod" then
				self.object:remove()
				return
			end

			local pla_pos = player:get_pos()
			if (pla_pos.y - pos.y) > 15 or (pla_pos.y - pos.y) < -15
			or (pla_pos.x - pos.x) > 15 or (pla_pos.x - pos.x) < -15
			or (pla_pos.z - pos.z) > 15 or (pla_pos.z - pos.z) < -15 then
				self.object:remove()
				return
			end

			if def and def.liquidtype == "source"
			and core.get_item_group(def.name, "water") ~= 0 then

				self.old_y = self.old_y or pos.y

				if not self.patience or self.patience <= 0 then
					self.patience = random(10, (45 - self.bait))
					self.bait = 0
				end

				if self.bob then
					effect(pos)
					if self.timer < self.patience then
						self.timer = self.timer + dtime
					else
						self.patience = 0
						self.timer = 0
						self.bob = false
					end
				else
					if self.timer < self.patience then
						self.timer = self.timer + dtime
					else
						self.bob = true
						self.patience = 1.4
						self.timer = 0

						self.object:set_velocity({x = 0, y = -1, z = 0})
						self.object:set_acceleration({x = 0, y = 3, z = 0})

						core.sound_play("default_water_footstep", {pos = pos, gain = 0.1}, true)
					end
				end
			else
				if self.old_y and pos.y > self.old_y then
					self.object:set_velocity({x = 0, y = 0, z = 0})
					self.object:set_acceleration({x = 0, y = 0, z = 0})
					self.object:set_pos({x = pos.x, y = self.old_y, z = pos.z})
				end

				if not self.bob then
					self.object:remove()
				end
			end
		end
	end
})

-- RETAINED FUNCTION: Refactored item filtering for universal compatibility
local function find_item(list, pos)
	local items = {}
	local data = core.get_biome_data and core.get_biome_data(pos)
	local biome = data and core.get_biome_name(data.biome) or ""

	for n = 1, #list do
		local item = list[n]
		if type(item) == "string" then
			table.insert(items, item)
		elseif type(item) == "table" and (item[2] == "" or biome:find(item[2])) then
			table.insert(items, item[1])
		end
	end

	return #items > 0 and items[random(#items)] or ""
end

-- Main Rod Action Function
local function use_rod(itemstack, player, pointed_thing)

	local pos = player:get_pos()
	local objs = core.get_objects_inside_radius(pos, 15)

	-- Reel in active bobbers
	for n = 1, #objs do
		local ent = objs[n]:get_luaentity()

		if ent and ent.fisher and ent.name == "standalone_fishing:bob_entity"
		and ent.fisher == player:get_player_name() then

			if ent.bob then
				local item
				local r = random(100)
				local rodpos = ent.object:get_pos() or pos
				rodpos.y = rodpos.y - 1

				-- Distribution odds maintained (86% fish, 10% junk, 4% bonus)
				if r < 86 then
					item = find_item(fish_items, rodpos)
				elseif r > 85 and r < 96 then
					item = find_item(junk_items, rodpos)
				else
					item = find_item(bonus_items, rodpos)
				end

				local item_name = item:split(" ")[1]
				local item_wear = item:split(" ")[2]

				if not core.registered_items[item_name] then
					item = default_item
				end

				item = ItemStack(item)

				if item_wear and core.registered_tools[item_name] then
					item:set_wear(65535 - item_wear)
				end

				local inv = player:get_inventory()
				if inv:room_for_item("main", item) then
					inv:add_item("main", item)
				else
					core.add_item(pos, item)
				end
			end

			ent.object:remove()
			return itemstack
		end
	end

	-- Cast rod mechanics 
	local playerpos = player:get_pos()
	local dir = player:get_look_dir()
	local cast_pos = {x = playerpos.x, y = playerpos.y + 1.5, z = playerpos.z}

	-- Safely falls back to default placement sound profiles if custom wave files aren't found
	core.sound_play("default_place_node", {pos = cast_pos, max_hear_distance = 10}, true)

	local obj = core.add_entity(cast_pos, "standalone_fishing:bob_entity")
	if obj then
		obj:set_velocity({x = dir.x * 8, y = dir.y * 8, z = dir.z * 8})
		obj:set_acceleration({x = dir.x * -3, y = -9.8, z = dir.z * -3})
		obj:get_luaentity().fisher = player and player:get_player_name()
	end

	itemstack:add_wear(65535 / 65)
	return itemstack
end

-- Area clean helper function
local function remove_bob(player)
	local objs = core.get_objects_inside_radius(player:get_pos(), 15)
	local name = player:get_player_name()
	for n = 1, #objs do
		local ent = objs[n]:get_luaentity()
		if ent and ent.name == "standalone_fishing:bob_entity" then
			if ent.fisher and ent.fisher == name then
				ent.object:remove()
			end
		end
	end
end

core.register_on_leaveplayer(function(player) remove_bob(player) end)
core.register_on_dieplayer(function(player) remove_bob(player) end)

-- Fishing Rod Tool Registration
core.register_tool("standalone_fishing:fishing_rod", {
	description = S("Fishing Rod (USE to cast and again when the time is right)"),
	groups = {tool = 1},
	inventory_image = "standalone_fishing_rod.png",
	wield_image = "standalone_fishing_rod.png^[transformFX",
	wield_scale = {x = 1.5, y = 1.5, z = 1},
	stack_max = 1,
	on_use = use_rod,
	sound = {breaks = "default_tool_breaks"}
})

core.register_craft({
	output = "standalone_fishing:fishing_rod",
	recipe = {
		{"","","group:stick"},
		{"","group:stick", string_item},
		{"group:stick","", string_item}
	}
})

core.register_craft({
	type = "fuel",
	recipe = "standalone_fishing:fishing_rod",
	burntime = 15
})

-- Complete original dataset array for fish processing (All 32 original types)
local fish = {
	{"Blue Fin", "bluefin", 2},
	{"Blue Ram Cichlid", "blueram", 2},
	{"Common Carp", "carp", 2},
	{"Cod", "cod", 2},
	{"Redtail Catfish", "catfish", 2},
	{"Clownfish", "clownfish", 2},
	{"Northern Pike", "pike", 2},
	{"Dusky Flathead", "flathead", 2},
	{"Plaice", "plaice", 2},
	{"Tiger Pufferfish", "pufferfish", -16},
	{"Coy", "coy", 2},
	{"European Flounder", "flounder", 2},
	{"Atlantic Salmon", "salmon", 2},
	{"Iceblue Zebra Cichlid", "cichlid", 2},
	{"Angler", "angler", 2},
	{"Moon Jellyfish", "jellyfish", 0},
	{"Pacific Mackerel", "mackerel", 2},
	{"Piranha", "piranha", 2},
	{"Rainbow Trout", "trout", 2},
	{"Red Snapper", "redsnapper", 2},
	{"Red Seahorse", "seahorse", 0},
	{"Green Seahorse", "seahorse_green", 0},
	{"Pink Seahorse", "seahorse_pink", 0},
	{"Blue Seahorse", "seahorse_blue", 0},
	{"Yellow Seahorse", "seahorse_yellow", 0},
	{"Yellowfin Tuna", "tuna", 2},
	{"Humboldt Squid", "squid", 0},
	{"White Shrimp", "shrimp", 0},
	{"Neon Tetra", "tetra", 1},
	{"Tilapia", "tilapia", 2},
	{"Golden Trevally", "trevally", 2},
	{"Stoplight Parrotfish", "parrot", 2}
}

-- Automatic standard loops processing items
for n = 1, #fish do
	local usage
	local groups = nil

	if fish[n][3] ~= 0 then
		usage = core.item_eat(fish[n][3])
		groups = {food_fish_raw = 1, standalone_fish = 1}
	end

	core.register_craftitem("standalone_fishing:fish_" .. fish[n][2], {
		description = S(fish[n][1]),
		inventory_image = "standalone_fish_" .. fish[n][2] .. ".png",
		on_use = usage,
		groups = groups
	})

	if groups then
		standalone_fishing.add_eatable("standalone_fishing:fish_" .. fish[n][2], fish[n][3])
	end
end

-- Override modifications matching initial file properties
core.override_item("standalone_fishing:fish_tetra", {light_source = 3})
core.override_item("standalone_fishing:fish_pufferfish", {groups = {flammable = 2}})

-- Standalone Worm Item
core.register_craftitem("standalone_fishing:worm", {
	description = S("Worm"),
	inventory_image = "standalone_worm.png",
	wield_image = "standalone_worm.png"
})

core.register_craft({
	output = "standalone_fishing:worm",
	recipe = {
		{"default:dirt", "default:dirt"}
	}
})

-- Universal mod compatibility alias mappings
core.register_alias("standalone_fishing:fish_raw", "standalone_fishing:fish_cichlid")
core.register_alias("standalone_fishing:fishing_rod_baited", "standalone_fishing:fishing_rod")
core.register_alias("standalone_fishing:fish_chichlid", "standalone_fishing:fish_cichlid")
