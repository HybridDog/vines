local vine_seed = 12

-- Nodes
local c_air = minetest.get_content_id("air")
local rope_side = "default_wood.png^vines_rope_shadow.png^vines_rope.png"

minetest.register_node("vines:rope_block", {
	description = "Rope",
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
	after_place_node = function(pos)
		local p = {x=pos.x, y=pos.y-1, z=pos.z}
		local n = minetest.get_node(p)
		if n.name == "air" then
			minetest.add_node(p, {name="vines:rope_end"})
		end
	end,
	after_dig_node = function(pos)
		local p = {x=pos.x, y=pos.y-1, z=pos.z}
		local n = minetest.get_node(p).name

		if n ~= 'vines:rope'
		and n ~= 'vines:rope_end' then
			return
		end

		local t1 = os.clock()
		local y1 = p.y
		local tab = {}
		local i = 1
		while n == 'vines:rope' do
			tab[i] = p
			i = i+1
			p.y = p.y-1
			n = minetest.get_node(p).name
		end 
		if n == 'vines:rope_end' then
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
		print(string.format("[vines] rope removed at ("..pos.x.."|"..pos.y.."|"..pos.z..") after: %.2fs", os.clock() - t1))
	end
})

minetest.register_node("vines:rope", {
	description = "Rope",
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

minetest.register_node("vines:rope_end", {
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

minetest.register_node("vines:vine", {
	description = "Vine",
	walkable = false,
	climbable = true,
	--buildable_to = true,
	drop = 'vines:vines',
	sunlight_propagates = true,
	paramtype = "light",
	tiles = { "vines_vine.png" },
	drawtype = "plantlike",
	inventory_image = "vines_vine.png",
	groups = { snappy = 3,flammable=2 },
	sounds = default.node_sound_leaves_defaults(),
})

minetest.register_node("vines:vine_rotten", {
	description = "Rotten vine",
	walkable = false,
	climbable = true,
	--buildable_to = true,
	drop = 'vines:vines',
	sunlight_propagates = true,
	paramtype = "light",
	tiles = { "vines_vine_rotten.png" },
	drawtype = "plantlike",
	inventory_image = "vines_vine_rotten.png",
	groups = { snappy = 3,flammable=2 },
	sounds = default.node_sound_leaves_defaults(),
	after_dig_node = function(pos, oldnode, _, digger)
		local inv = digger:get_inventory()
		local item = 'vines:vines'
		local p = {x=pos.x, y=pos.y-1, z=pos.z}
		local vine = oldnode.name
		while minetest.get_node(p).name == vine do
			minetest.remove_node(p)
			dropitem(item, p, inv)
			p.y = p.y-1
		end
		local about = {x=pos.x, y=pos.y+1, z=pos.z}
		if minetest.get_node(about).name == vine then
			minetest.add_node(about, {name="vines:vine"})
		end
	end 
})

--ABM
local function get_vine_random(pos)
	return PseudoRandom(math.abs(pos.x+pos.y*3+pos.z*5)+vine_seed)
end

minetest.register_abm({ --"sumpf:leaves", "jungletree:leaves_green", "jungletree:leaves_yellow", "jungletree:leaves_red", "default:leaves"
	nodenames = {"default:dirt_with_grass"},
	interval = 80,
	chance = 200,
	action = function(pos)
		local pr = get_vine_random(pos)
		if pr:next(1,4) == 1 then
			return
		end
		
		local p = {x=pos.x, y=pos.y-1, z=pos.z}
		local n = minetest.get_node(p)
		
		if n.name == "air" then
			minetest.add_node(p, {name="vines:vine"})
			print("[vines] vine grew at: ("..p.x..", "..p.y..", "..p.z..")")
		end
	end
})

minetest.register_abm({
	nodenames = {"vines:vine"},
	interval = 5,
	chance = 4,
	action = function(pos)

		local s_pos = "("..pos.x..", "..pos.y..", "..pos.z..")"

		--remove if top node is removed
		if minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z}).name == "air" then 
			minetest.remove_node(pos)
			print("[vines] vine removed at: "..s_pos)
			return
		end

		minetest.add_node(pos, {name="vines:vine_rotten"})

		local p = {x=pos.x, y=pos.y-1, z=pos.z}
		local n = minetest.get_node(p)
		local pr = get_vine_random(pos)

		--the second argument in the random function represents the average height
		if pr:next(1,4) == 1 then 
			print("[vines] vine ended at: "..s_pos)
			return
		end

		if n.name =="air" then
			minetest.add_node(p, {name="vines:vine"})
			print("[vines] vine got longer at: ("..p.x..", "..p.y..", "..p.z..")")
		end
	end
})

minetest.register_abm({
	nodenames = {"vines:vine_rotten"},
	interval = 60,
	chance = 4,
	action = function(pos)
		
		local p = {x=pos.x, y=pos.y-1, z=pos.z}
		local n = minetest.get_node(p)
		local n_about = minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z}).name
		local pr = get_vine_random(pos)
		
		-- only remove if nothing is hangin on the bottom of it.
		if (
				n.name ~="vines:vine"
			and n.name ~="vines:vine_rotten"
			and n_about ~= "default:dirt"
			and n_about ~= "default:dirt_with_grass"
			and pr:next(1,4) ~= 1
		)
		or n_about == "air" then
			minetest.remove_node(pos)
			print("[vines] rotten vine disappeared at: ("..pos.x..", "..pos.y..", "..pos.z..")")
		end
		
	end
})

minetest.register_abm({
	nodenames = {"default:dirt"},
	interval = 36000,
	chance = 10,
	action = function(pos)
		
		local p = {x=pos.x, y=pos.y-1, z=pos.z}
		local n = minetest.get_node(p)
		
		--remove if top node is removed
		if n.name == "air"
		and is_node_in_cube ({"vines:vine"}, pos, 3) then
			minetest.add_node(p, {name="vines:vine"})
			print("[vines] vine grew at: ("..p.x..", "..p.y..", "..p.z..")")
		end 
	end
})

minetest.register_abm({
	nodenames = {"vines:rope_end"},
	interval = 1,
	chance = 1,
	action = function(pos, node, active_object_count, active_object_count_wider)
		
		local p = {x=pos.x, y=pos.y-1, z=pos.z}
		local n = minetest.get_node(p)
		
		--remove if top node is removed
		if n.name == "air" then
			minetest.add_node(pos, {name="vines:rope"})
			minetest.add_node(p, {name="vines:rope_end"})
		end 
	end
})

function is_node_in_cube(nodenames, pos, s)
	for i = -s, s do
		for j = -s, s do
			for k = -s, s do
				local n = minetest.get_node_or_nil({x=pos.x+i, y=pos.y+j, z=pos.z+k})
				if n == nil
				or n.name == 'ignore'
				or table_contains(nodenames, n.name) == true then
					return true
				end
			end
		end
	end
	return false
end

table_contains = function(t, v)
	for _,i in pairs(t) do
		if i == v then
			return true
		end
	end
	return false
end

-- craft rope
minetest.register_craft({
	output = 'vines:rope_block',
	recipe = {
		{'', 'default:wood', ''},
		{'', 'vines:vines', ''},
		{'', 'vines:vines', ''},
	}
})

minetest.register_craftitem("vines:vines", {
	description = "Vines",
	inventory_image = "vines_vine.png",
})
print("[Vines] v1.1 loaded")
