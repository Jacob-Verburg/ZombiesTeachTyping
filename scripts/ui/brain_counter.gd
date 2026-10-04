class_name BrainCounter
extends Panel
## The brain counter pill: a brain icon and a number. Shows whatever its owner gives it: the HUD feeds
## the level's run total (never the saved wallet during a run), the main menu and the Crypt Closet (Stories
## 4.2 / 4.4) feed the wallet. Placeholder chrome until Story 5.0; the count-up tick and pop are 5.0/5.1.
## Never focusable, never blocks the mouse.


## Shows `n`. A negative count is a caller bug: logged, shown as 0.
func set_count(n: int) -> void:
	if n < 0:
		Log.error(&"ui", "BrainCounter.set_count(%d): negative count shown as 0" % n)
		n = 0
	%CountLabel.text = str(n)
