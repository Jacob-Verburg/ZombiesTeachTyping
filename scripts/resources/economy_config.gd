class_name EconomyConfig
extends Resource
## Brains rules that are not per-level or per-item: the shipped values live in data/economy.tres.
## Item prices live on each CosmeticItem; the defaults here are neutral.

## Brains the welcome gift grants once on a new save (FR44: 100). Read by Story 4.5.
@export var welcome_bonus: int = 0
