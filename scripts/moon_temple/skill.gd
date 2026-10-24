extends Resource
## Game-side data. Jeff FX recipes remain independent from damage and input.
@export var id := "wind_sword"
@export var title := "追风剑"
@export var cooldown := 0.5
@export var damage := 24.0
@export var effect_id := "classic_xianxia_sword"
@export var target_mode := "enemy"
@export var animation := "cast"
@export var radius := 65.0
@export var duration := 0.8
@export var release_frame := -1
@export var heal_amount := 35.0
@export var shield_amount := 40.0
@export_range(0.25, 4.0, 0.05) var effect_scale := 1.0

@export var display_offset := Vector2.ZERO
@export var impact_frame := -1
