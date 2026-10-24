extends Resource
## Courtyard-only placement and playback; original effect recipes stay untouched.
@export var travel_effect := "classic_wuxia_dash"
@export var landing_effect := "classic_wuxia_dust"
@export var foot_offset := Vector2(0, 5)
@export_range(0.25, 2.0) var travel_scale := 1.25
@export_range(0.25, 2.0) var landing_scale := 1.05
@export_range(0.2, 1.0) var ground_depth := 0.6
@export_range(0.5, 3.0) var travel_speed := 2.0
@export_range(0.5, 3.0) var landing_speed := 1.7
@export_range(0.0, 1.0) var travel_opacity := 0.78
@export_range(0.0, 1.0) var landing_opacity := 0.82
@export var behind_feet := 12.0
@export var mark_distance := 46.0
@export_range(1, 3) var max_travel_marks := 2
