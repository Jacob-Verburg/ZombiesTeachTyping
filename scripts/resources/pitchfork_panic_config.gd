class_name PitchforkPanicConfig
extends LevelConfig
## Pitchfork Panic's own tuning numbers (Story 8.3), on top of the shared LevelConfig fields. A
## PitchforkPanicConfig is a LevelConfig, so RunFrame, TypingInput and the HUD read it unchanged. Real
## values live in data/levels/pitchfork_panic.tres; the defaults here are neutral. The one number that is
## not here is ChaseModel.STEPS_PER_WPM_EQ_MIN (1 WPM-eq = 5 steps a minute, GDD).

## FR70: how many steps the mob starts behind the zombie.
@export var start_gap_steps: float = 0.0
## FR70: the mob's speed at run time 0, in WPM-eq.
@export var mob_start_wpm_eq: float = 0.0
## FR70: how many WPM-eq the mob adds every mob_accel_every_s (applied continuously).
@export var mob_accel_wpm_eq: float = 0.0
## FR70: the seconds in which the mob gains mob_accel_wpm_eq.
@export var mob_accel_every_s: float = 0.0
## FR71: pixels one step moves the zombie (half the 32 px sprite).
@export var step_px: float = 0.0
## FR71: where the camera keeps the zombie, as a fraction of the screen width (0.6 = 60%).
@export var zombie_screen_x_frac: float = 0.0
## FR71: the mob is on screen whenever the gap is below this many steps.
@export var mob_visible_gap_steps: float = 0.0
## Look value: seconds the zombie sprite takes to walk one step.
@export var step_time_s: float = 0.0


## Empty when the numbers can run a level; otherwise the first problem found.
func validate() -> String:
	if not (duration_s > 0.0 and is_finite(duration_s)):
		return "duration_s must be above 0"
	if target_mode != TargetMode.PARAGRAPH:
		return "target_mode must be PARAGRAPH"
	if not case_sensitive:
		return "case_sensitive must be true"
	if not space_is_input:
		return "space_is_input must be true"
	if paragraphs == null:
		return "paragraphs is missing"
	if not (start_gap_steps > 0.0 and is_finite(start_gap_steps)):
		return "start_gap_steps must be above 0"
	if not (mob_start_wpm_eq >= 0.0 and is_finite(mob_start_wpm_eq)):
		return "mob_start_wpm_eq must not be negative"
	if not (mob_accel_wpm_eq >= 0.0 and is_finite(mob_accel_wpm_eq)):
		return "mob_accel_wpm_eq must not be negative"
	if mob_start_wpm_eq == 0.0 and mob_accel_wpm_eq == 0.0:
		return "the mob needs a start speed or an acceleration"
	if not (mob_accel_every_s > 0.0 and is_finite(mob_accel_every_s)):
		return "mob_accel_every_s must be above 0"
	if not (step_px > 0.0 and is_finite(step_px)):
		return "step_px must be above 0"
	if not (zombie_screen_x_frac > 0.0 and zombie_screen_x_frac < 1.0):
		return "zombie_screen_x_frac must be between 0 and 1"
	if not (mob_visible_gap_steps > 0.0 and is_finite(mob_visible_gap_steps)):
		return "mob_visible_gap_steps must be above 0"
	if not (step_time_s >= 0.0 and is_finite(step_time_s)):
		return "step_time_s must not be negative"
	return ""
