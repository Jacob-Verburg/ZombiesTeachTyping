class_name ChaseBackdrop
extends ParallaxBackdrop
## A Pitchfork Panic setting's backdrop (Story 10.4): the same 4-layer ParallaxBackdrop (every behaviour,
## the missing-texture warning and the scroll rounding are the parent's), plus the one thing a chase setting
## adds, the cover the zombie dives into when it escapes. The cover lives on the backdrop scene rather than
## on LevelTheme so each setting is whole in one scene (a cornfield can never be registered with the
## forest's log) and LevelTheme stays level-agnostic. PitchforkPanicLevel hands the sheet to %EscapeCover in
## its _ready; a plain ParallaxBackdrop in the slot keeps the built-in bush.

## The setting's escape cover: 3 frames of 48x48 (frame 0 still, 1-2 rustled), standing on row 46.
@export var escape_cover_sheet: Texture2D
