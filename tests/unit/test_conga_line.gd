extends GutTest
## Conga line (Story 3.4, FR35): join, chase, bob, facing, the cap with no hidden nodes, the ×N badge
## and "never shrinks". A bare Node2D is the leader; the line is disabled and driven by step(delta).
## Dance (Story 3.5): a bigger bounce and a beat flip instead of the bob; the chase is unchanged.

const CongaScene: PackedScene = preload("res://scenes/levels/zombie_run/conga_line.tscn")
const THEME_PATH: String = "res://data/ui_theme.tres"
const LEADER_X: float = 200.0

var _leader: Node2D
var _line: CongaLine


func _make(max_drawn: int = 3) -> CongaLine:
	_leader = Node2D.new()
	_leader.position.x = LEADER_X
	add_child_autofree(_leader)
	_line = CongaScene.instantiate() as CongaLine
	_line.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(_line)
	_line.configure(_leader, max_drawn)
	return _line


func _steps(count: int, delta: float = 1.0 / 60.0) -> void:
	for i: int in count:
		_line.step(delta)


func _slot(i: int) -> float:
	return _leader.position.x - (i + 1) * CongaLine.SPACING_PX


func _party_zombies_under(node: Node) -> int:
	var count: int = 1 if node is PartyZombie else 0
	for child: Node in node.get_children():
		count += _party_zombies_under(child)
	return count


func _badge() -> PanelContainer:
	return _line.get_node("%Badge") as PanelContainer


func _faces_left(follower: PartyZombie) -> bool:
	return (follower.get_node("Body") as AnimatedSprite2D).flip_h


func test_scene_shape() -> void:
	_make()
	var followers: Node = _line.get_node("%Followers")
	var badge: PanelContainer = _badge()
	assert_eq(followers.get_parent(), _line)
	assert_eq(badge.get_parent(), _line)
	assert_gt(badge.get_index(), followers.get_index(), "the badge draws on top of the followers")
	assert_false(badge.visible)
	assert_eq(badge.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_join_below_the_cap() -> void:
	_make()
	_line.join(150.0)
	var followers: Array[PartyZombie] = _line.get_followers()
	assert_eq(followers.size(), 1)
	assert_eq(followers[0].get_parent(), _line.get_node("%Followers"))
	assert_eq(followers[0].position, Vector2(150.0, 0.0), "at the join spot, before any step")
	assert_eq(_line.get_joined_count(), 1)
	assert_eq(_line.get_drawn_count(), 1)
	assert_false(_line.is_badge_shown())


func test_get_followers_is_a_copy() -> void:
	_make()
	_line.join(150.0)
	_line.get_followers().clear()
	assert_eq(_line.get_followers().size(), 1)


func test_cap_creates_no_extra_nodes() -> void:
	_make(3)
	for i: int in 5:
		_line.join(LEADER_X)
	assert_eq(_party_zombies_under(_line), 3, "no hidden nodes beyond the cap")
	assert_eq(_line.get_drawn_count(), 3)
	assert_eq(_line.get_joined_count(), 5)
	assert_true(_line.is_badge_shown())
	assert_eq(_line.get_badge_text(), "×5")


func test_badge_counts_everyone_at_the_shipped_cap() -> void:
	_make(12)
	for i: int in 12:
		_line.join(LEADER_X)
	assert_false(_line.is_badge_shown(), "12 fit without a badge")
	_line.join(LEADER_X)
	assert_true(_line.is_badge_shown())
	assert_eq(_line.get_badge_text(), "×13")
	assert_eq(_party_zombies_under(_line), 12)


func test_followers_converge_to_their_slots() -> void:
	_make()
	for i: int in 3:
		_line.join(LEADER_X)
	_steps(300)
	var followers: Array[PartyZombie] = _line.get_followers()
	for i: int in followers.size():
		assert_almost_eq(followers[i].position.x, _slot(i), 0.5, "follower %d" % i)


func test_line_follows_a_scoot_and_never_passes_the_zombie() -> void:
	_make()
	for i: int in 3:
		_line.join(LEADER_X)
	_steps(300)
	_leader.position.x += 48.0
	var followers: Array[PartyZombie] = _line.get_followers()
	var last: Array[float] = []
	for follower: PartyZombie in followers:
		last.append(follower.position.x)
	for s: int in 120:
		_line.step(1.0 / 60.0)
		for i: int in followers.size():
			var x: float = followers[i].position.x
			assert_true(x >= last[i], "follower %d only moves forward (step %d)" % [i, s])
			assert_true(x < _leader.position.x - CongaLine.SPACING_PX + 0.001, "follower %d never passes" % i)
			last[i] = x
	for i: int in followers.size():
		assert_almost_eq(followers[i].position.x, _slot(i), 0.5, "caught up: follower %d" % i)


func test_chase_is_frame_rate_independent() -> void:
	_make()
	_line.join(LEADER_X - 100.0)
	_steps(60, 1.0 / 60.0)
	var at_60: float = _line.get_followers()[0].position.x
	_make()
	_line.join(LEADER_X - 100.0)
	_steps(30, 1.0 / 30.0)
	assert_almost_eq(_line.get_followers()[0].position.x, at_60, 1.0)


func test_newcomer_walks_back_to_the_tail_facing_left() -> void:
	_make()
	_line.join(LEADER_X)
	_line.join(LEADER_X)
	_steps(300)
	_line.join(LEADER_X - CongaLine.SPACING_PX)
	var newcomer: PartyZombie = _line.get_followers()[2]
	_line.step(1.0 / 60.0)
	assert_true(_faces_left(newcomer), "walking back to the tail")
	var previous: float = newcomer.position.x
	for s: int in 300:
		_line.step(1.0 / 60.0)
		assert_true(newcomer.position.x <= previous, "only moves back")
		previous = newcomer.position.x
	assert_almost_eq(newcomer.position.x, _slot(2), 0.5, "ends on the tail slot")
	assert_false(_faces_left(newcomer), "faces right again once there")
	var followers: Array[PartyZombie] = _line.get_followers()
	for i: int in followers.size():
		assert_almost_eq(followers[i].position.x, _slot(i), 0.5, "order kept: follower %d" % i)


func test_bob_is_whole_pixels_and_a_wave() -> void:
	_make()
	for i: int in 3:
		_line.join(_slot(i))
	var followers: Array[PartyZombie] = _line.get_followers()
	var differed: bool = false
	for s: int in 120:
		_line.step(1.0 / 60.0)
		for i: int in followers.size():
			var y: float = followers[i].position.y
			assert_eq(y, roundf(y), "whole pixels")
			assert_true(y >= -CongaLine.BOB_PX and y <= 0.0, "within [-BOB_PX, 0] (y %.2f)" % y)
			assert_eq(followers[i].position.x, _slot(i), "the bob never changes x")
		if followers[0].position.y != followers[1].position.y:
			differed = true
	assert_true(differed, "neighbours bob out of phase")


func test_bob_runs_on_accumulated_delta() -> void:
	_make()
	_line.join(_slot(0))
	var follower: PartyZombie = _line.get_followers()[0]
	_line.step(0.125)
	assert_eq(follower.position.y, -CongaLine.BOB_PX, "top of the bob a quarter period in")
	_line.step(0.25)
	assert_eq(follower.position.y, 0.0, "bottom of the bob three quarters in")
	_line.step(0.0)
	assert_eq(follower.position.y, 0.0, "no time, no change")


func test_no_step_nothing_moves() -> void:
	_make()
	for i: int in 3:
		_line.join(LEADER_X - i * 10.0)
	_line.step(1.0 / 60.0)
	var before: Array[Vector2] = []
	for follower: PartyZombie in _line.get_followers():
		before.append(follower.position)
	_leader.position.x += 100.0
	for i: int in _line.get_followers().size():
		assert_eq(_line.get_followers()[i].position, before[i], "frozen until step (pause)")


func test_real_tree_pause_freezes_the_line() -> void:
	var holder: Node = Node.new()
	holder.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child_autofree(holder)
	_leader = Node2D.new()
	_leader.position.x = LEADER_X
	holder.add_child(_leader)
	_line = CongaScene.instantiate() as CongaLine
	holder.add_child(_line)
	_line.configure(_leader, 3)
	_line.join(LEADER_X - 10.0)
	await get_tree().process_frame
	var before: Vector2 = _line.get_followers()[0].position
	get_tree().paused = true
	_leader.position.x += 100.0
	await get_tree().process_frame
	await get_tree().process_frame
	var frozen: Vector2 = _line.get_followers()[0].position
	get_tree().paused = false
	assert_eq(frozen, before, "a paused tree freezes the line")
	await get_tree().process_frame
	assert_ne(_line.get_followers()[0].position, before, "it moves again once unpaused")


func test_no_leader_is_harmless() -> void:
	_line = CongaScene.instantiate() as CongaLine
	_line.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(_line)
	_line.configure(null, 3)
	_line.join(10.0)
	_line.step(0.1)
	assert_eq(_line.get_followers()[0].position, Vector2(10.0, 0.0))


func test_badge_rides_the_last_drawn_follower() -> void:
	_make(3)
	for i: int in 4:
		_line.join(LEADER_X)
	_steps(300)
	var badge: PanelContainer = _badge()
	var last: PartyZombie = _line.get_followers()[2]
	assert_gt(badge.size.y, 0.0, "the badge has a size")
	assert_gt(badge.size.x, 0.0)
	assert_almost_eq(badge.position.x, last.position.x - 8.0, 0.01, "left edge on the follower's left edge")
	assert_true(badge.position.y + badge.size.y <= last.position.y - 32.0, "bottom above the hat")
	assert_almost_eq(badge.position.y + badge.size.y, last.position.y + CongaLine.BADGE_BOTTOM_Y, 0.01)
	for s: int in 30:
		_line.step(1.0 / 60.0)
		assert_almost_eq(badge.position.y + badge.size.y, last.position.y + CongaLine.BADGE_BOTTOM_Y, 0.01, "rides the bob")


func test_badge_grows_to_the_right() -> void:
	_make(1)
	for i: int in 2:
		_line.join(LEADER_X)
	_steps(300)
	var left: float = _badge().position.x
	var width: float = _badge().size.x
	for i: int in 98:
		_line.join(LEADER_X)
	_steps(1)
	assert_eq(_line.get_badge_text(), "×100")
	assert_gt(_badge().size.x, width, "wider for more digits")
	assert_almost_eq(_badge().position.x, left, 0.5, "same left edge")


func test_theme_font_has_the_times_glyph() -> void:
	var theme: Theme = load(THEME_PATH) as Theme
	assert_not_null(theme.default_font)
	assert_true(theme.default_font.has_char(0xD7), "Press Start 2P has ×")


func test_never_shrinks() -> void:
	_make(3)
	var joined: int = 0
	var drawn: int = 0
	for i: int in 20:
		if i % 3 != 2:
			_line.join(LEADER_X - i)
		_leader.position.x += 7.0
		_steps(5)
		assert_true(_line.get_joined_count() >= joined)
		assert_true(_line.get_drawn_count() >= drawn)
		assert_eq(_party_zombies_under(_line), _line.get_drawn_count())
		joined = _line.get_joined_count()
		drawn = _line.get_drawn_count()
	assert_eq(joined, 14)
	assert_eq(drawn, 3)


# --- dance (Story 3.5) ------------------------------------------------------

func test_dance_flag() -> void:
	_make()
	assert_false(_line.is_dancing())
	_line.dance()
	assert_true(_line.is_dancing())


func test_dance_bounce_is_whole_pixels_bigger_than_the_bob_and_a_ripple() -> void:
	_make()
	for i: int in 3:
		_line.join(_slot(i))
	_line.dance()
	var followers: Array[PartyZombie] = _line.get_followers()
	var deepest: float = 0.0
	var differed: bool = false
	for s: int in 120:
		_line.step(1.0 / 60.0)
		for i: int in followers.size():
			var y: float = followers[i].position.y
			assert_eq(y, roundf(y), "whole pixels")
			assert_true(y >= -CongaLine.DANCE_HOP_PX and y <= 0.0, "within [-DANCE_HOP_PX, 0] (y %.2f)" % y)
			deepest = minf(deepest, y)
		if followers[0].position.y != followers[1].position.y:
			differed = true
	assert_lt(deepest, -CongaLine.BOB_PX, "the dance bounces higher than the walk bob")
	assert_true(differed, "neighbours dance out of phase")


func test_settled_followers_flip_on_the_beat() -> void:
	_make()
	for i: int in 2:
		_line.join(_slot(i))
	_line.dance()
	var followers: Array[PartyZombie] = _line.get_followers()
	var left: Array[bool] = [false, false]
	var right: Array[bool] = [false, false]
	var differed: bool = false
	for s: int in 120:
		_line.step(1.0 / 60.0)
		for i: int in followers.size():
			if _faces_left(followers[i]):
				left[i] = true
			else:
				right[i] = true
		if _faces_left(followers[0]) != _faces_left(followers[1]):
			differed = true
	for i: int in followers.size():
		assert_true(left[i] and right[i], "follower %d faces both ways over the beats" % i)
	assert_true(differed, "the flips ripple down the line")


func test_dancing_followers_still_converge_and_never_pass() -> void:
	_make()
	for i: int in 3:
		_line.join(LEADER_X - 100.0 * (i + 1))
	_line.dance()
	var followers: Array[PartyZombie] = _line.get_followers()
	for s: int in 300:
		_line.step(1.0 / 60.0)
		for i: int in followers.size():
			assert_true(followers[i].position.x < _leader.position.x - CongaLine.SPACING_PX + 0.001, "never passes")
	for i: int in followers.size():
		assert_almost_eq(followers[i].position.x, _slot(i), 0.5, "follower %d settles on its slot" % i)


func test_join_during_the_dance() -> void:
	_make(2)
	_line.join(_slot(0))
	_line.dance()
	_steps(30)
	_line.join(LEADER_X - CongaLine.SPACING_PX)
	assert_eq(_line.get_drawn_count(), 2, "a newcomer joins mid-dance")
	var newcomer: PartyZombie = _line.get_followers()[1]
	_line.step(1.0 / 60.0)
	assert_true(_faces_left(newcomer), "walks back to the tail first")
	_steps(300)
	assert_almost_eq(newcomer.position.x, _slot(1), 0.5, "then dances on its slot")
	var joined: int = _line.get_joined_count()
	_line.join(LEADER_X)
	assert_eq(_line.get_joined_count(), joined + 1, "beyond the cap the badge ticks")
	assert_true(_line.is_badge_shown())
	assert_eq(_line.get_badge_text(), "×3")
	_steps(60)
	assert_eq(_line.get_joined_count(), 3, "never goes down")
	assert_eq(_line.get_drawn_count(), 2)


func test_dance_frozen_without_step() -> void:
	_make()
	for i: int in 3:
		_line.join(_slot(i))
	_line.dance()
	_steps(7)
	var before: Array[Vector2] = []
	var facing: Array[bool] = []
	for follower: PartyZombie in _line.get_followers():
		before.append(follower.position)
		facing.append(_faces_left(follower))
	await get_tree().process_frame
	await get_tree().process_frame
	for i: int in _line.get_followers().size():
		assert_eq(_line.get_followers()[i].position, before[i], "frozen until step (pause)")
		assert_eq(_faces_left(_line.get_followers()[i]), facing[i])


func test_badge_rides_the_dance() -> void:
	_make(3)
	for i: int in 4:
		_line.join(LEADER_X)
	_steps(300)
	_line.dance()
	var badge: PanelContainer = _badge()
	var last: PartyZombie = _line.get_followers()[2]
	var lowest: float = 0.0
	for s: int in 60:
		_line.step(1.0 / 60.0)
		lowest = minf(lowest, last.position.y)
		assert_true(_line.is_badge_shown())
		assert_almost_eq(badge.position.y + badge.size.y, last.position.y + CongaLine.BADGE_BOTTOM_Y, 0.01, "rides the dance")
	assert_lt(lowest, -CongaLine.BOB_PX, "the last follower really danced")
