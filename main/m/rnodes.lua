local M = {}

M.CENTER_W = 480
M.CENTER_H = 480

M.x_ratio = 1
M.y_ratio = 1

function M.clamp(x, min, max)
	return x < min and min or (x > max and max or x)
end

function M.get_screen_aspect_ratio()
	local window_x, window_y = window.get_size()
	local stretch_x = window_x / gui.get_width()
	local stretch_y = window_y / gui.get_height()

	M.x_ratio = stretch_x / math.min(stretch_x, stretch_y)
	M.y_ratio = stretch_y / math.min(stretch_x, stretch_y)

	M.CENTER_W = gui.get_width() / 2
	M.CENTER_H = gui.get_height() / 2
	return  M.x_ratio, M.y_ratio
end

M.shadow_offset = vmath.vector3(4, -4, 0)

function M.register(self, param)
	assert(param.node, "You must provide a node")
	self.registered_nodes = self.registered_nodes or {}
	local node = type(param.node) == "string" and gui.get_node(param.node) or param.node
	local obj = {
		node = node,
		scale = gui.get_scale(node),
		position = param.position or gui.get_position(node),
		value = param.value,
		press_cb = param.press_cb,
		release_cb = param.release_cb,
		over_cb = param.over_cb,
		drag_cb = param.drag_cb,
		size = gui.get_size(node)
	}
	if param.shadow then
		obj.shadow = type(param.shadow) == "string" and gui.get_node(param.shadow) or param.shadow
		gui.set_position(obj.shadow, M.shadow_offset)
	end
	table.insert(self.registered_nodes, 1, obj)
	return obj
end

local function is_enabled(node)
	local enabled = gui.is_enabled(node)
	local parent = gui.get_parent(node)
	if not enabled or not parent then
		return enabled
	else
		return is_enabled(parent)
	end
end

--- Returns absolute position including parent node(s).
function M.get_position(node)
	local node_pos = gui.get_position(node)
	local parent = gui.get_parent(node)
	while parent do
		node_pos = node_pos + gui.get_position(parent)
		parent = gui.get_parent(parent)
	end
	return node_pos
end

function M.sort_nodes(self)
	if not self.registered_nodes then return end
	for i = 1, #self.registered_nodes - 1 do
		gui.move_above(self.registered_nodes[i].node, self.registered_nodes[i + 1].node)
	end
end

function M.move_to_top(self, node)
	if not self.registered_nodes then return end
	local index = -1
	for i = 1, #self.registered_nodes do
		if self.registered_nodes[i].node == node then
			index = i
			break
		end
	end
	if index < 1 then
		print("node is not registered")
		return
	end
	local r_node = self.registered_nodes[index]
	for i = index, 2, -1 do
		self.registered_nodes[i] = self.registered_nodes[i - 1]
	end
	self.registered_nodes[1] = r_node
	-- table.remove(self.registered_nodes, index)
	-- table.insert(self.registered_nodes, 1, node)

	-- sort_nodes(self)
	-- pprint(self.registered_nodes)
end

function M.unregister(self, node)
	if not self.registered_nodes then return end
	local index = -1
	for i = 1, #self.registered_nodes do
		if self.registered_nodes[i].node == node then
			index = i
			break
		end
	end
	if index < 1 then
		print("node is not registered")
		return
	end
	table.remove(self.registered_nodes, index)
end

function M.on_touch(self, action)
	if not self.registered_nodes then return end
	if action.pressed then
		for _,r_node in ipairs(self.registered_nodes) do
			local node = r_node.node
			if is_enabled(node) and gui.pick_node(node, action.x, action.y) then
				r_node.pressed = true
				return node, r_node
			end
		end
	elseif action.released then
		for _,r_node in ipairs(self.registered_nodes) do
			local node = r_node.node
			local pressed = r_node.pressed
			r_node.pressed = false
			if is_enabled(node) and gui.pick_node(node, action.x, action.y) and pressed then
				return node, r_node
			end
		end
	end
	return nil
end

function M.on_hover(self, x, y, skip_node)
	if not self.registered_nodes then return end
	for _,r_node in ipairs(self.registered_nodes) do
		local node = r_node.node
		if node ~= skip_node and is_enabled(node) and gui.pick_node(node, x, y) then
			return node, r_node
		end
	end
	return nil
end

function M.aabb(self, x, y, skip_rnode)
	if not self.registered_nodes then return end
	assert(skip_rnode, "!")
	assert(skip_rnode.size, "! size of node not found")
	local width = (skip_rnode.size.x * .7) / 2
	local height =(skip_rnode.size.y * .7) / 2
	for _,r_node in ipairs(self.registered_nodes) do
		local node = r_node.node
		if node ~= skip_rnode.node and is_enabled(node)	and
		(   gui.pick_node(node, x, y)
			or gui.pick_node(node, x - width, y - height)
			or gui.pick_node(node, x + width, y - height)
			or gui.pick_node(node, x + width, y + height)
			or gui.pick_node(node, x - width, y + height))
			then
			return node, r_node
		end
	end
	return nil
end

function M.delete_node(self, node, effect)
	local tree = gui.get_tree(node)
	local mt = effect or "dissolve"
	for i, v in pairs(tree) do
		if gui.get_flipbook(v) ~= hash("") then
			gui.set_material(v, mt)
		end
	end
	gui.animate(node, "color.w", 0, gui.EASING_LINEAR, .5, 0, function(self, n)
		gui.delete_node(n)
		-- for _, v in pairs(tree) do
		-- 	gui.reset_material(v)
		-- end
	end)
end


local TOUCH = hash("touch")
M.ENTER = 1
M.OUT = 2
M.REPEAT = 3

function M.on_input(self, action_id, action)
	if action_id == TOUCH then
		M.get_screen_aspect_ratio()
		local node, r_node = M.on_touch(self, action)
		local action_pos = vmath.vector3(action.x  * M.x_ratio, action.y * M.y_ratio, 0)
		-- local action_pos = vmath.vector3(action.x, action.y, 0)
		-- print(action_pos)

		if node and r_node and action.pressed then

			local available = true
			if r_node.press_cb then available = r_node.press_cb(self, r_node, action) end

			if available then
				self.r_node = r_node
				self.dragged_pos = action_pos
				local initial_pos = gui.get_position(node)
				r_node.offset = action_pos - initial_pos
				self.dragging = true

				if self.r_node.shadow then
					gui.animate(self.r_node.shadow, "position.y", -10, gui.EASING_OUTBACK, 0.1)
				end
			end

		elseif node and action.released then

			if self.r_node.shadow then
				gui.animate(self.r_node.shadow, "position", M.shadow_offset, gui.EASING_OUTBACK, 0.1)
			end

			if self.r_node.release_cb then self.r_node.release_cb(self, self.r_node, action) end

			self.dragging = false
			self.r_node = nil

		end

		-- update position of dragged object if we're dragging it
		if self.dragging then
			if self.r_node.shadow then
				gui.animate(self.r_node.shadow, "position.x", (M.CENTER_W - action.x)/30 , gui.EASING_OUTELASTIC, 0.1)
			end

			if self.r_node.drag_cb then self.r_node.drag_cb(self, self.r_node, action, action_pos) end
		end

		return node ~= nil or self.dragging

	elseif action_id == nil and not self.dragging then
		M.get_screen_aspect_ratio()
		local index = 1

		for _,v in ipairs(self.registered_nodes) do
			if v.over_cb then
				local node = v.node
				local is_pick = is_enabled(node) and gui.pick_node(node, action.x, action.y)
				if is_pick and index == 1 then
					index = index + 1
					if not v.overed then
						v.overed = true
						v.over_cb(self, v, action, M.ENTER) -- enter
					else
						v.over_cb(self, v, action, M.REPEAT) -- repeat
					end
				elseif v.overed and (not is_pick or index > 1) then
					v.overed = false
					v.over_cb(self, v, action, M.OUT) -- out
				end
			end
		end
	end
	return nil
end


return M