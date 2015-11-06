local vine_seed = 12

-- intllib support
local S, register_node
if minetest.global_exists("intllib") then
	S = intllib.Getter()
	function register_node(name, data)
		if data.description then
			data.description = S(data.description)
		end
		return minetest.register_node(name, data)
	end
else
	S = function(s) return s end
	register_node = minetest.register_node
end

local function log(text)
	minetest.log("action", "[vines] "..text)
end

-- Nodes
local c_air = minetest.get_content_id("air")
local rope_side = "default_wood.png^vines_rope_shadow.png^vines_rope.png"

register_node("vines:rope_block", {
	description = "rope",
	sunlight_propagates = true,
	paramtype = "light",
	drops = "",
	tiles = {
		rope_side,
		rope_side,
		"default_wood.png",
		"default_wood.png",
		rope_side,
	},
	drawtype = "cube",
	groups = { snappy = 3},
	sounds =  default.node_sound_leaves_defaults(),
	on_construct = function(pos)
		local p = {x=pos.x, y=pos.y-1, z=pos.z}
		local n = minetest.get_node(p)
		if n.name == "air" then
			minetest.add_node(p, {name="vines:rope_end"})
		end
	end,
	after_destruct = function(pos)
		local p = {x=pos.x, y=pos.y-1, z=pos.z}
		local n = minetest.get_node(p).name

		if n ~= "vines:rope"
		and n ~= "vines:rope_end" then
			return
		end

		local t1 = os.clock()
		local y1 = p.y
		local tab = {}
		local i = 1
		while n == "vines:rope" do
			tab[i] = p
			i = i+1
			p.y = p.y-1
			n = minetest.get_node(p).name
		end
		if n == "vines:rope_end" then
			tab[i] = p
		end
		local y0 = p.y

		local manip = minetest.get_voxel_manip()
		local p1 = {x=p.x, y=y0, z=p.z}
		local p2 = {x=p.x, y=y1, z=p.z}
		local pos1, pos2 = manip:read_from_map(p1, p2)
		area = VoxelArea:new({MinEdge=pos1, MaxEdge=pos2})
		nodes = manip:get_data()

		for i in area:iterp(p1, p2) do
			nodes[i] = c_air
		end

		manip:set_data(nodes)
		manip:write_to_map()
		manip:update_map() -- <— this takes time
		log(string.format("rope removed at "..minetest.pos_to_string(pos).." after: %.2fs", os.clock() - t1))
	end
})

register_node("vines:rope", {
	description = "rope",
	walkable = false,
	climbable = true,
	sunlight_propagates = true,
	paramtype = "light",
	tiles = { "vines_rope.png" },
	inventory_image = "vines_rope.png",
	drawtype = "plantlike",
	groups = {},
	sounds =  default.node_sound_leaves_defaults(),
	selection_box = {
		type = "fixed",
		fixed = {-1/7, -1/2, -1/7, 1/7, 1/2, 1/7},
	},

})

register_node("vines:rope_end", {
	walkable = false,
	climbable = true,
	sunlight_propagates = true,
	paramtype = "light",
	drops = "",
	tiles = { "vines_rope.png" },
	drawtype = "plantlike",
	groups = {},
	sounds =  default.node_sound_leaves_defaults(),
	after_place_node = function(pos)
		yesh  = {x = pos.x, y= pos.y-1, z=pos.z}
		minetest.add_node(yesh, "vines:rope")
	end,
	selection_box = {
		type = "fixed",
		fixed = {-1/7, -1/2, -1/7, 1/7, 1/2, 1/7},
	},
})

local function dropitem(item, pos, inv)
	if inv
	and inv:room_for_item("main", item) then
		inv:add_item("main", item)
		return
	end
	minetest.add_item(pos, item)
end

register_node("vines:vine", {
	description = "tendril",
	walkable = false,
	climbable = true,
	--buildable_to = true,
	drop = "vines:vines",
	sunlight_propagates = true,
	paramtype = "light",
	tiles = { "vines_vine.png" },
	drawtype = "plantlike",
	inventory_image = "vines_vine.png",
	groups = { snappy = 3,flammable=2 },
	sounds = default.node_sound_leaves_defaults(),
})

register_node("vines:vine_rotten", {
	description = "rotten tendril",
	walkable = false,
	climbable = true,
	--buildable_to = true,
	drop = "vines:vines",
	sunlight_propagates = true,
	paramtype = "light",
	tiles = { "vines_vine_rotten.png" },
	drawtype = "plantlike",
	inventory_image = "vines_vine_rotten.png",
	groups = { snappy = 3,flammable=2 },
	sounds = default.node_sound_leaves_defaults(),
	after_dig_node = function(pos, oldnode, _, digger)
		local inv = digger:get_inventory()
		local item = "vines:vines"
		local p = {x=pos.x, y=pos.y-1, z=pos.z}
		local vine = oldnode.name
		while minetest.get_node(p).name == vine do
			minetest.remove_node(p)
			dropitem(item, p, inv)
			p.y = p.y-1
		end
		pos.y = pos.y+1
		if minetest.get_node(pos).name == vine then
			minetest.add_node(pos, {name="vines:vine"})
		end
	end
})


--ABMs

local set = vector.set_data_to_pos
local get = vector.get_data_from_pos

local disallowed_abm_ps = {}
local function abm_disallowed(pos)
	local z = math.floor(pos.z/5)
	local y = math.floor(pos.y/5)
	local x = math.floor(pos.x/5)
	if get(disallowed_abm_ps, z,y,x) then
		return true
	end
	set(disallowed_abm_ps, z,y,x, true)
	if not disallowed_abm_ps.aborting then
		disallowed_abm_ps.aborting = true
		minetest.after(4, function()
			disallowed_abm_ps = {}
		end)
	end
	return false
end


local function get_vine_random(pos)
	return PseudoRandom(math.abs(pos.x+pos.y*3+pos.z*5)+vine_seed)
end


local function grass_vine_abm(p)
	local pr = get_vine_random(p)
	if pr:next(1,4) == 1 then
		return
	end

	p.y = p.y-1
	if minetest.get_node(p).name == "air" then
		minetest.add_node(p, {name="vines:vine"})
		log("vine grew at: "..minetest.pos_to_string(p))
	end
end

minetest.register_abm({ --"sumpf:leaves", "jungletree:leaves_green", "jungletree:leaves_yellow", "jungletree:leaves_red", "default:leaves"
	nodenames = {"default:dirt_with_grass"},
	interval = 80,
	chance = 200,
	catch_up = false,
	action = function(pos)
		if abm_disallowed(pos) then
			return
		end
		grass_vine_abm(pos)
		--[[minetest.delay_function(800, function(pos)
			local node = minetest.get_node(pos)
			if node.name == "default:dirt_with_grass" then
				grass_vine_abm(pos, node)
			end
		end, pos)]]
	end
})


local function dirt_vine_abm(pos)
	local p = {x=pos.x, y=pos.y-1, z=pos.z}

	--remove if top node is removed
	if minetest.get_node(p).name == "air"
	and is_node_in_cube({"vines:vine"}, pos, 3) then
		minetest.add_node(p, {name="vines:vine"})
		log("vine grew at: "..minetest.pos_to_string(p))
	end
end

minetest.register_abm({
	nodenames = {"default:dirt"},
	interval = 36000,
	chance = 10,
	catch_up = false,
	action = function(pos)
		dirt_vine_abm(pos)
		--[[minetest.delay_function(6000, function(pos)
			local node = minetest.get_node(pos)
			if node.name == "default:dirt" then
				dirt_vine_abm(pos, node)
			end
		end, pos)]]
	end
})


local function vine_abm(pos)
	local s_pos = minetest.pos_to_string(pos)

	--remove if top node is removed
	if minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z}).name == "air" then
		minetest.remove_node(pos)
		log("vine removed at: "..s_pos)
		return
	end

	minetest.add_node(pos, {name="vines:vine_rotten"})

	local pr = get_vine_random(pos)
	--the second argument in the random function represents the average height
	if pr:next(1,4) == 1 then
		log("vine ended at: "..s_pos)
		return
	end

	pos.y = pos.y-1
	if minetest.get_node(pos).name =="air" then
		minetest.add_node(pos, {name="vines:vine"})
		log("vine got longer at: "..minetest.pos_to_string(pos))
	end
end

minetest.register_abm({
	nodenames = {"vines:vine"},
	interval = 5,
	chance = 4,
	catch_up = false,
	action = function(pos)
		if abm_disallowed(pos) then
			return
		end
		vine_abm(pos)
		--[[minetest.delay_function(10, function(pos)
			local node = minetest.get_node(pos)
			if node.name == "vines:vine" then
				vine_abm(pos, node)
			end
		end, pos)]]
	end
})


local function rotten_vine_abm(pos)
	local n_under = minetest.get_node({x=pos.x, y=pos.y-1, z=pos.z}).name
	local n_above = minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z}).name

	-- only remove if nothing is hangin on the bottom of it.
	if (
		n_under ~= "vines:vine"
		and n_under ~= "vines:vine_rotten"
		and n_above ~= "default:dirt"
		and n_above ~= "default:dirt_with_grass"
		and (get_vine_random(pos)):next(1,4) ~= 1
	)
	or n_above == "air" then
		minetest.remove_node(pos)
		log("rotten vine disappeared at: "..minetest.pos_to_string(pos))
	end
end

minetest.register_abm({
	nodenames = {"vines:vine_rotten"},
	interval = 60,
	chance = 4,
	catch_up = false,
	action = function(pos)
		if abm_disallowed(pos) then
			return
		end
		rotten_vine_abm(pos)
		--[[minetest.delay_function(59, function(pos)
			local node = minetest.get_node(pos)
			if node.name == "vines:vine_rotten" then
				rotten_vine_abm(pos, node)
			end
		end, pos)]]
	end
})

minetest.register_abm({
	nodenames = {"vines:rope_end"},
	interval = 1,
	chance = 1,
	action = function(pos, node)
		pos.y = pos.y-1
		if minetest.get_node(pos).name ~= "air" then
			return
		end

		minetest.add_node(pos, node)

		pos.y = pos.y+1
		node.name = "vines:rope"
		minetest.add_node(pos, node)
	end
})

local function table_contains(t, v)
	for _,i in pairs(t) do
		if i == v then
			return true
		end
	end
	return false
end

function is_node_in_cube(nodenames, pos, s)
	for i = -s, s do
		for j = -s, s do
			for k = -s, s do
				local n = minetest.get_node_or_nil({x=pos.x+i, y=pos.y+j, z=pos.z+k})
				if not n
				or n.name == "ignore"
				or table_contains(nodenames, n.name) == true then
					return true
				end
			end
		end
	end
	return false
end

-- craft rope
minetest.register_craft({
	output = "vines:rope_block",
	recipe = {
		{"", "default:wood", ""},
		{"", "vines:vines", ""},
		{"", "vines:vines", ""},
	}
})

minetest.register_craftitem("vines:vines", {
	description = S("vines"),
	inventory_image = "vines_vine.png",
})

minetest.log("info", "[Vines] v1.1-special loaded")
