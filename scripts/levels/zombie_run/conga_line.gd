class_name CongaLine
extends Node2D
## The conga line behind the player zombie (Story 3.4, FR35): every party-hat zombie the run makes joins
## the end of the line and follows the zombie, bobbing, for the rest of the run.
##
## Logical vs view: the level owns the authoritative conga count (+1 in the same call that resolves a
## villager). This node is only the view: join() is called when a villager's poof ends, so its joined
## count catches up with the level's count as poofs finish.
##
## Cap: at most max_drawn followers are ever instanced (the level passes ZombieRunConfig.conga_max_drawn).
## Once more than that have joined, a pumpkin "×N" badge (N = everyone joined this run) rides above the
## last drawn follower. A join beyond the cap creates no node, not even a hidden one: only the badge
## number goes up.
##
## Movement: follower i (0 = right behind the zombie) chases the slot leader.x - (i + 1) * SPACING_PX on
## the ground line with frame-rate-independent smoothing, so the line follows every scoot and amble with
## a short ease. A follower never moves forward past leader.x - SPACING_PX, so it never passes the zombie
## and a newcomer never jumps. Each follower bobs on y with a phase offset by its index (a wave down the
## line); the bob never touches x. A follower faces left only while walking back to its slot.
## Story 3.6: a follower plays walk while it moves faster than WALK_SPEED_MIN_PX_S (its own x change this
## step) and idle once settled; the bob stays (the index-phased wave is the conga read, the legs do the
## rest).
## Time is accumulated from delta in step(), never read from the clock, so a tree pause freezes the line
## and tests are deterministic. No randomness, no allocation and no logging per frame.
##
## Dance (Story 3.5, FR36): dance() switches every follower's walk bob for a bigger bounce and a facing
## flip per beat, both phased by index so the line ripples. The chase is unchanged (the leader has stopped,
## so the followers settle on their slots); a follower still walking back to its slot faces left as
## usual. It lasts until the run frame is freed, draws no randomness, and joins still work mid-dance.
## Dancing followers play idle plus the code bounce and flip (decision in Story 3.6: no party-zombie
## dance sheet).
##
## Never shrinks: there is no removal API.

const PARTY_ZOMBIE_SCENE: PackedScene = preload("res://scenes/characters/party_zombie.tscn")

## Look values, not GDD numbers (tuned by eye).
## One party zombie's opaque width, so they touch like a conga.
const SPACING_PX: float = 16.0
## Chase smoothing rate in 1/s; the steady lag is about speed / rate.
const CHASE_RATE: float = 12.0
const BOB_PX: float = 2.0
const BOB_HZ: float = 2.0
## Bob phase step between neighbours, in radians.
const BOB_PHASE_STEP: float = 0.6
## Badge anchor relative to the last drawn follower: left edge on the sprite's left edge, bottom just
## above the hat (the sheet's top row is y -31).
const BADGE_LEFT_PX: float = -8.0
const BADGE_BOTTOM_Y: float = -33.0
const BADGE_PREFIX: String = "×"
## Followers move this far before they count as walking back (faces left).
const FACE_DEADZONE_PX: float = 0.5
## A follower moving faster than this (px/s, its own x change) plays walk; slower, it has settled: idle.
const WALK_SPEED_MIN_PX_S: float = 4.0
## Dance bounce height, bounces per second (a facing flip on every beat) and the beat offset between
## neighbours, so they flip in a ripple.
const DANCE_HOP_PX: float = 4.0
const DANCE_BEAT_HZ: float = 2.0
const DANCE_BEAT_OFFSET: float = 0.5

var _leader: Node2D
var _max_drawn: int = 0
var _joined: int = 0
var _time: float = 0.0
var _followers: Array[PartyZombie] = []
var _dancing: bool = false
var _dance_time: float = 0.0

@onready var _followers_root: Node2D = %Followers
@onready var _badge: PanelContainer = %Badge
@onready var _badge_label: Label = %BadgeLabel


## The level calls this in its _ready(). The cap comes in here so the line never reads the config.
func configure(leader: Node2D, max_drawn: int) -> void:
	_leader = leader
	_max_drawn = max_drawn


## Adds one zombie to the end of the line, at line-local x `from_x` (where its villager poofed).
func join(from_x: float) -> void:
	_joined += 1
	if _followers.size() < _max_drawn:
		var follower: PartyZombie = PARTY_ZOMBIE_SCENE.instantiate() as PartyZombie
		follower.position = Vector2(from_x, 0.0)
		_followers_root.add_child(follower)
		_followers.append(follower)
	_update_badge()


## Starts the end dance; it runs until the line is freed.
func dance() -> void:
	if _dancing:
		return
	_dancing = true
	_dance_time = 0.0


func is_dancing() -> bool:
	return _dancing


func _process(delta: float) -> void:
	step(delta)


## One frame of chase and bob (or dance). Public so tests can drive it.
func step(delta: float) -> void:
	_time += delta
	if _dancing:
		_dance_time += delta
	if _leader == null:
		return
	var leader_x: float = _leader.position.x
	var weight: float = 1.0 - exp(-CHASE_RATE * delta)
	for i: int in _followers.size():
		var follower: PartyZombie = _followers[i]
		var x: float = follower.position.x
		var slot: float = leader_x - (i + 1) * SPACING_PX
		var new_x: float = lerpf(x, slot, weight)
		var walking_back: bool = slot < x - FACE_DEADZONE_PX
		new_x = minf(new_x, maxf(x, leader_x - SPACING_PX))
		follower.position.x = new_x
		if _dancing or delta <= 0.0 or absf(new_x - x) / delta <= WALK_SPEED_MIN_PX_S:
			follower.play_idle()
		else:
			follower.play_walk()
		if _dancing:
			follower.position.y = -roundf(
				DANCE_HOP_PX * absf(sin(PI * DANCE_BEAT_HZ * _dance_time + i * BOB_PHASE_STEP)))
			var beat: int = int(floorf(DANCE_BEAT_HZ * _dance_time + i * DANCE_BEAT_OFFSET))
			follower.face_left(walking_back or beat % 2 == 1)
		else:
			follower.position.y = -roundf(BOB_PX * (0.5 + 0.5 * sin(TAU * BOB_HZ * _time + i * BOB_PHASE_STEP)))
			follower.face_left(walking_back)
	_place_badge()


func get_joined_count() -> int:
	return _joined


func get_drawn_count() -> int:
	return _followers.size()


## The drawn followers in join order (a copy).
func get_followers() -> Array[PartyZombie]:
	return _followers.duplicate()


func get_badge_text() -> String:
	return _badge_label.text


func is_badge_shown() -> bool:
	return _badge.visible


func _update_badge() -> void:
	_badge.visible = _joined > _max_drawn
	if not _badge.visible:
		return
	_badge_label.text = "%s%d" % [BADGE_PREFIX, _joined]
	_badge.reset_size()
	_place_badge()


## Bottom-left just above the last drawn follower's head, riding its bob. Anchoring the left edge means a
## longer number grows to the right and never clips off the left of the screen.
func _place_badge() -> void:
	if not _badge.visible or _followers.is_empty():
		return
	var last: PartyZombie = _followers.back()
	_badge.position = Vector2(
		last.position.x + BADGE_LEFT_PX, last.position.y + BADGE_BOTTOM_Y - _badge.size.y
	)
