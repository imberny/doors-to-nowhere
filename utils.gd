class_name Utils
extends Object

enum CollisionLayers {
	PLAYER = 1 << 0,
	STATIC = 1 << 1, # static geometry
	DYNAMIC = 1 << 2, # non-static objects
	PORTAL_STATIC = 1 << 11 # portal solid edges
	ENTITY_IN_PORTAL = 1 << 12 # objects within a portal
}

enum VisualLayers {
	MAIN_CAMERA = 1 << 0, # visible from main camera
	PORTAL_CAMERA = 1 << 1, # visible through portal cameras
	PORTAL_CULL = 1 << 2 # not visible through portal cameras
}

static func bit_mask_set(bit_mask: int, bits_to_set: int) -> int:
	return bit_mask | bits_to_set


static func bit_mask_unset(bit_mask: int, bits_to_unset: int) -> int:
	return bit_mask & ~bits_to_unset


static func children_to_list_recursive(node: Node) -> Array:
	var arr := []
	for child in node.get_children():
		arr = arr + children_to_list_recursive(child)
	arr.push_front(node)
	return arr

