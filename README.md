# Defold Cards FX Kit

![Example](/example.png)

This is a small kit of scripts and shaders for card games and similar games. Made for the GUI interface, does not use the camera or Game objects. Includes:

- Click and dragging card detection module. Does not depend on the aspect ratio of the screen. See `main\m\rnodes.lua`.
- A module for detecting clicks on interface buttons. See `main\m\si.lua`
- GUI material and shader for the effect of perspective distortion, so-called fake 3D.
- Dissolve effect shader adapted for GUI material.
- Freeze effect shader.
- Material and background texture repeat shader. (Uses a separate atlas with a texture that is a multiple of a square of two). 
- Example Usage. See `main\gui\ui.gui_script`.
- A slightly modified render script.
- Mouse click/single touch is bound to action "touch"

Check out [HTML5 demo ](https://dragosha.com/defold/cards-fx-kit/)

For correct work it is also necessary to make noise texture passing in render script. For this purpose `textures.script` and slightly modified render script are used. Also note, by default gui camera is used for pure 2D and works in the range Z from -1 to 1. For the effect of distortions in render script changed the projection matrix for GUI, instead of -1..1 near and far planes are set to -300..300.

```lua
-- projection for gui
--
local function get_gui_projection(camera, state)
    return vmath.matrix4_orthographic(0, state.window_width, 0, state.window_height, -300, 300)
end
```

The `rnodes.lua` and `si.lua` modules are very similar in functionality and code inside. Both of them use the node table lookup and trigger callbacks when specific events occur for a found node. I separated them mainly by semantic content, so as not to mix tables with cards and tables with buttons. But if you want, you can combine them and use a more suitable variant.

## How to use

Set material `/assets/material/gui/gui.material` for whole your gui. Also add other materials to the GUI material list if you want to use some effects for the card. Each effect has its own material for each effect.

Include the module `rnodes.lua` in the script.

```lua
local rnodes = require "main.m.rnodes"
```

Create the cards and register them in the rnodes module. Note that in addition to the main node, to which the interaction with the cursor or touch is defined, you can pass the card value and a node with the card shadow to the registrator, it will change its position depending on the interaction with the card.

```lua
 rnodes.register(self, {
		node = node,
		value = uid,
		position = position,
		shadow = "shadow",
		release_cb = release_cb,
		press_cb = press_cb,
		drag_cb = drag_cb,
		over_cb = over_cb
	})
```

### Press callback

`function press_cb(self, instance, action)` where
Instance is the table of the registered node, contains the node itself `instance.node`, the value `instance.value`, the starting position `instance.position`, the starting scale `instance.scale`.
`Action` is a table received from the on_input event.
In this callback you can return ‘true’ to accept the following steps (drag and release) or ‘false’ to prevent it.


### Release callback

`function release_cb(self, instance, action)`

Same as press, but only release :-). Click happened you can do something with the node.


### Drag callback

Invoked every time a node changes its position and is in a dragged state.

`function drag_cb(self, instance, action, action_pos)`

`action_pos` a vmath.vector3 it's modified position of the node considering the screen aspect ratio.
To visual dragging a node do following code in this callback function:

```lua
	local position = action_pos - instance.offset
	local node = instance.node
	gui.set_position(node, position)
```

### Over callback

Invoked every time the cursor hovers over a node.

`function over_cb(self, instance, action, enter)`

Here we have additional argument `enter` it takes one of three values: it takes one of three values:

- `rnodes.ENTER` the cursor appears above the node
- `rnodes.OUT` the cursor has moved outside the node
- `rnodes.REPEAT` the cursor moves over the node. 


### On input

Forward on_input calls to `rnodes.on_input` function to detect input:

```lua
function on_input(self, action_id, action)
	if rnodes.on_input(self, action_id, action) then
		return true
	end
end
```

---

Learn, modify, adapt and use in your games!

Happy Defolding!

---

## Credits

This project and included assets are licensed under the terms of the CC0 1.0 Universal license. It's developed and supported by [@Dragosha](https://github.com/Dragosha).

Font `Troika.otf` (c) JOEL CARROUCHE used under the FREE FONT LICENSE version 1.2, February 2019
