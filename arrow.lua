
-- Localise functions
local floor, min, max = math.floor, math.min, math.max


bows.nothing = function(self, target, hp, user, lastpos)
	return self
end


bows.on_hit_object = function(self, target, hp, user, lastpos)

	target:punch(user, 1.0, {
		full_punch_interval = 1.0,
		damage_groups = {fleshy = hp},
	}, nil)

	bows.arrow_remove(self)

	return self
end


bows.on_hit_node = function(self, pos, user, lastpos)

	if not minetest.registered_nodes[minetest.get_node(pos).name].node_box then

		local mpos = {
			x = pos.x - lastpos.x,
			y = pos.y - lastpos.y,
			z = pos.z - lastpos.z
		}

		local npos = {
			x = bows.rnd(pos.x),
			y = bows.rnd(pos.y),
			z = bows.rnd(pos.z)
		}

		local m = {x = -0.6, y = -0.6, z = -0.6}
		local bigest = {x = mpos.x, y = mpos.y, z = mpos.z}

		if bigest.x < 0 then
			bigest.x = bigest.x * -1
			m.x = 0.6
		end

		if bigest.y < 0 then
			bigest.y = bigest.y * -1
			m.y = 0.6
		end

		if bigest.z < 0 then
			bigest.z = bigest.z * -1
			m.z = 0.6
		 end

		local b = max(bigest.x, bigest.y, bigest.z)

		if b == bigest.x then
			pos.x = npos.x + m.x
		elseif b == bigest.y then
			pos.y = npos.y + m.y
		else
			pos.z = npos.z + m.z
		end

		self.object:set_pos(pos)
	end

	return self
end


bows.rnd = function(r)
	return floor(r + 0.5)
end


bows.arrow_remove = function(self)

	self.object:remove()

	return self
end


--= Functions inspired from Kaeza's Firearms mod

local function minmax(x, y)
	return min(x, y), max(x, y)
end


local function pos_in_box(p, b1, b2)

	local xmin, xmax = minmax(b1.x, b2.x)
	local ymin, ymax = minmax(b1.y, b2.y)
	local zmin, zmax = minmax(b1.z, b2.z)

	return p.x >= xmin and p.x <= xmax
			and p.y >= ymin and p.y <= ymax
			and p.z >= zmin and p.z <= zmax
end


local function get_obj_box(obj)

	local box

	if obj:is_player() then
		box = {-.5, -.5, -.5, .5, 1.5, .5}
	else
		box = obj:get_luaentity().collisionbox
				or {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}
	end

	local p = obj:get_pos()
	local x1, y1, z1, x2, y2, z2 = unpack(box)

	return {x = x1 + p.x, y = y1 + p.y, z = z1 + p.z},
			{x = x2 + p.x, y = y2 + p.y, z = z2 + p.z}
end

--= END (Thanks Kaeza :)


minetest.register_entity("bows:arrow",{

	hp_max = 10,
	visual = "wielditem",
	visual_size = {x = .20, y = .20},
	collisionbox = {0,0,0,0,0,0},
	physical = false,
	textures = {"air"},

	on_activate = function(self, staticdata)

		if not self then
			self.object:remove()
			return
		end

		if bows.tmp and bows.tmp.arrow ~= nil then

			self.arrow = bows.tmp.arrow
			self.user = bows.tmp.user
			self.name = bows.tmp.name
			self.dmg = bows.registed_arrows[self.name].damage

			bows.tmp = nil

			self.object:set_properties({textures = {self.arrow}})
		else
			self.object:remove()
		end
	end,

	stuck = false,
	arrow = true,
	timer = 20,
	x = 0,
	y = 0,
	z = 0,

	on_step = function(self, dtime)

		self.timer = self.timer - dtime

		if self.stuck then

			if self.target
			and self.target:get_hp() <= 1 then
				self.timer=-1
			end

			if self.timer < 0 then
				bows.arrow_remove(self)
			end

			return self
		end

		local pos = self.object:get_pos()
		local nod = minetest.get_node(pos)

		if (self.user == nil or self.timer < 16)
		or (minetest.registered_nodes[nod.name]
		and minetest.registered_nodes[nod.name].walkable) then

			self.object:set_velocity({x = 0, y = 0, z = 0})
			self.object:set_acceleration({x = 0, y = 0, z = 0})
			self.stuck = true

			bows.registed_arrows[self.name].on_hit_node(self, pos, self.user,{
				x = self.x, y = self.y, z = self.z})

			minetest.sound_play(bows.registed_arrows[self.name].on_hit_sound, {
				pos = pos, gain = 1.0, max_hear_distance = 7})

			return self
		end

		self.x = pos.x
		self.y = pos.y
		self.z = pos.z

		for i, ob in pairs(minetest.get_objects_inside_radius(pos, 3.0)) do

			if ob
			and ( (bows.pvp
			and ob:is_player()
			and ob:get_player_name() ~= self.user:get_player_name() )

			or (ob:get_luaentity()
			and ob:get_luaentity().physical
			and ob:get_luaentity().name ~= "__builtin:item") ) then

				-- Object specific collision detection
				local p1, p2 = get_obj_box(ob)

				if pos_in_box(pos, p1, p2) then

					self.object:set_velocity({x = 0, y = 0, z = 0})
					self.object:set_acceleration({x = 0, y = 0, z = 0})
					self.stuck = true

					bows.on_hit_object(self, ob, self.dmg, self.user,{
						x = self.x, y = self.y, z = self.z})

					bows.registed_arrows[self.name].on_hit_object(
						self, ob, self.dmg, self.user,
						{x = self.x, y = self.y, z = self.z})

					minetest.sound_play(
						bows.registed_arrows[self.name].on_hit_sound, {
							pos = pos, gain = 1.0, max_hear_distance = 7})

					return self
				end
			end
		end

		return self
	end,
})
