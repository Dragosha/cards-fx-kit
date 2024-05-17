local M = {}

local function ensure_node(node_or_node_id)
	return type(node_or_node_id) == "string" and gui.get_node(node_or_node_id) or node_or_node_id
end

--- Convenience function to acquire input focus
function M.acquire()
	msg.post("#", "acquire_input_focus")
end

--- Convenience function to release input focus
function M.release()
	msg.post("#", "release_input_focus")
end

M.TOUCH = hash("touch")
M.LONGTAP = 0.8
--- Aspect ration horizontal and vertical multiplicators
M.x_ratio = 1
M.y_ratio = 1
M.CENTER_W = 480
M.CENTER_H = 480
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

--- Register a node and a callbacks to invoke when the node receives input
---@param self userdata
---@param param table {node, callback, press_cb, over_cb, longtap_cb, drag_cb, value}
function M.register(self, param)
	assert(type(param) == 'table', "You must provide a table with parameters, node, callbacks, etc.")
	self.si_nodes = self.si_nodes or {}
	self.si_longtap = self.si_longtap or {}

	local node = ensure_node(param.node)
	local instance = {
		callback = param.callback,
		press_cb = param.press_cb,
		over_cb = param.over_cb,
		node = node,
		scale = gui.get_scale(node),
		value = param.value,
		longtap_cb = param.longtap_cb,
		drag_cb = param.drag_cb,
	}
	if param.index then table.insert(self.si_nodes, param.index, instance)
	else table.insert(self.si_nodes, instance)
	end
end

--- Unregister a previously registered node or all nodes
-- registered from the calling script
-- @param node_or_string string
function M.unregister(self, node_or_string)
	if not node_or_string then
		self.si_nodes = {}
		self.si_longtap = {}
	else
		local node = ensure_node(node_or_string)
		for index, value in ipairs(self.si_nodes) do
			if value.node == node then
				table.remove(self.si_nodes, index)
				break
			end
		end
		self.si_longtap[node] = nil
	end
end

--- Shake node effect
---@param self any
---@param node userdata
---@param initial_scale vmath.vector3 
local function shake(self, node, initial_scale)
	local scale = initial_scale
	gui.cancel_animation(node, "scale.x")
	gui.cancel_animation(node, "scale.y")
	gui.set_scale(node, scale * 1.2)
	gui.animate(node, "scale.x", scale.x, gui.EASING_OUTELASTIC, 0.8)
	gui.animate(node, "scale.y", scale.y, gui.EASING_OUTELASTIC, 0.8, 0.05, function()
		gui.set_scale(node, scale)
	end)
end
M.shake = shake

local function is_enabled(node)
	local enabled = gui.is_enabled(node)
	local parent = gui.get_parent(node)
	if not enabled or not parent then
		return enabled
	else
		return is_enabled(parent)
	end
end

--- Forward on_input calls to this function to detect input
-- for registered nodes
---@param action_id hash
---@param action table
---@return true if input a registerd node received input
function M.on_input(self, action_id, action)
	if action_id == M.TOUCH then
		M.get_screen_aspect_ratio()
		if action.pressed then
			for _,v in ipairs(self.si_nodes) do
				local node = v.node
				if is_enabled(node) and gui.pick_node(node, action.x, action.y) then
					v.pressed = true
					if v.longtap_cb then
						v.startTime = socket.gettime()
						self.si_longtap[node] = v
					end
					if v.press_cb then
						v.press_cb(self, v)
						-- shake(self, node, v.scale)
					end

					self.some_is_pressed = true
					if v.drag_cb then
						v.offset = vmath.vector3(action.x  * M.x_ratio, action.y * M.y_ratio, 0) - gui.get_position(node)
						self.si_dragable_instance = v
					end
					return true, node, v
				end
			end
		elseif action.released then
			for _,v in ipairs(self.si_nodes) do
				self.some_is_pressed = nil
				self.si_dragable_instance = nil
				local node = v.node
				local pressed = v.pressed
				v.pressed = false
				self.si_longtap[node] = nil
				if is_enabled(node) and gui.pick_node(node, action.x, action.y) and pressed then
					if v.callback then v.callback(self, v) end
					return true, node, v
				end
			end
		elseif action.repeated then
			for _,v in pairs(self.si_longtap) do
				self.some_is_pressed = nil
				self.si_dragable_instance = nil
				local node = v.node
				local pressed = v.pressed
				local t = socket.gettime() - v.startTime
				if t >= M.LONGTAP then
					if is_enabled(node) and gui.pick_node(node, action.x, action.y) and pressed then
						if v.longtap_cb then v.longtap_cb(self, v) end
						self.si_longtap[node] = nil
						v.pressed = false
						return true, node, v
					end
				end
			end
		end
		if self.si_dragable_instance then
			if self.si_dragable_instance.drag_cb then
				local position = vmath.vector3(action.x  * M.x_ratio, action.y * M.y_ratio, 0) - self.si_dragable_instance.offset
				self.si_dragable_instance.drag_cb(self, self.si_dragable_instance, action, position)
			end
		end
	elseif action_id == nil and not self.some_is_pressed then
		for _,v in ipairs(self.si_nodes) do
			if v.over_cb then
				local node = v.node
				if not v.overed and is_enabled(node) and gui.pick_node(node, action.x, action.y) then
					v.overed = true
					v.over_cb(self, v, true)
				elseif v.overed and not gui.pick_node(node, action.x, action.y) then
					v.overed = false
					v.over_cb(self, v, false)
				end
			end
		end
	end
	return self.some_is_pressed or false
end

return M
