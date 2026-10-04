class_name TargetSource
extends RefCounted
## What the player types next. LetterBagSource now; WordSource (Epic 6) and ParagraphSource (Epic 8)
## later. Pure logic: no nodes, no autoloads. This base is a safe no-op so TypingSession can be
## tested with a stub subclass.


## The `n` targets following the current one (so a queue is current() + peek(3)). Never consumes.
func peek(_n: int) -> Array[String]:
	return []


## The target the player must type now, or "" when there is none.
func current() -> String:
	return ""


## Consumes the current target; the next one becomes current().
func advance() -> void:
	pass
