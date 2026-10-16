extends Node3D
## Put any Node3D object/effect beneath this node; both landmark kinds use the
## same resolver. The parent chooses camera/model units via surface_transform.
var surface: RefCounted:
	set(value):
		if surface != null and surface.updated.is_connected(refresh): surface.updated.disconnect(refresh)
		surface = value
		if surface != null: surface.updated.connect(refresh)
		refresh()
@export var landmark_id := "face:10":
	set(value):
		landmark_id = value
		refresh()
@export var normal_offset := 0.0:
	set(value):
		normal_offset = value
		refresh()
var surface_transform := Transform3D.IDENTITY:
	set(value):
		surface_transform = value
		refresh()

func refresh() -> void:
	var anchor: Dictionary = surface.resolve(landmark_id) if surface != null else {}
	visible = not anchor.is_empty()
	if not visible: return
	var pose: Transform3D = anchor.transform
	pose.origin += anchor.normal*normal_offset
	transform = surface_transform*pose
