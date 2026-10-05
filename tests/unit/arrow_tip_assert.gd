class_name ArrowTipAssert
extends RefCounted
## Shared check for the down_arrow.png sprite on a Zombie Run target (Story 3.6). The sprite is a 16 x 16
## cell with the tip's ink on cell row 14 (its bottom edge is y 15) and the centre at x 8, so the icon
## position plus (8, 15) is the tip the old Polygon2D arrow had.


static func assert_tip(test: GutTest, target: Node, tip_y: float) -> void:
	var icon: Sprite2D = target.get_node("%Arrow/Icon") as Sprite2D
	test.assert_not_null(icon, "the arrow is a sprite")
	if icon == null:
		return
	test.assert_false(icon.centered)
	test.assert_eq(icon.texture.resource_path, "res://assets/sprites/props/down_arrow.png")
	test.assert_eq(icon.position + Vector2(8, 15), Vector2(0, tip_y), "the tip stays where it was")
	var tag: Control = target.get_node("%Tag") as Control
	test.assert_eq(tag.position.y - tip_y, 4.0, "the tag top is 4 px below the tip")
