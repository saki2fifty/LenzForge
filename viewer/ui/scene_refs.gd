extends RefCounted
## Resolve serialized UI references once, then let scripts update state and signals.
## Layout, labels, themes and control ranges live in studio.tscn.

static func bind(target: Node) -> void:
	assert(target.has_meta("scene_refs"), "Instantiate the saved studio scene before binding its UI.")
	var references: Dictionary = target.get_meta("scene_refs")
	for property in references:
		var value: Variant = _resolve(target, references[property])
		var previous: Variant = target.get(property)
		if previous is Array and value is Array:
			previous.assign(value)
		else:
			target.set(property, value)

static func _resolve(origin: Node, value: Variant) -> Variant:
	if value is NodePath: return origin.get_node(value)
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = _resolve(origin, value[key])
		return result
	if value is Array:
		var result := []
		for item in value: result.append(_resolve(origin, item))
		return result
	return value

static func action(target: Node, key: String, callback: Callable) -> void:
	var actions: Dictionary = target.get("ui_actions")
	assert(actions.has(key), "Missing scene action: " + key)
	for button in actions[key]: button.pressed.connect(callback)
