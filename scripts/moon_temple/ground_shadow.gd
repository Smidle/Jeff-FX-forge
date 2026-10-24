extends Node2D
## Pixel-aligned soft footprint plus small contact shadows under planted boots.
var feet: Array[float] = [0.0]
var height := 0.0
var width := 22.0
var _pose_key := ""
const MAX_HOP := 12.0

func _ready() -> void:
	z_as_relative = false
	z_index = -3 # Ground art -10, then shadow, ground effects -2, actors above.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func set_pose(contacts: Array, elevation: float, ground_offset: Vector2) -> void:
	var new_feet: Array[float] = []
	for point in contacts: new_feet.append(roundf(float(point)))
	var new_height := snappedf(maxf(0, elevation), 0.5)
	var key := str(new_feet)+":"+str(new_height)+":"+str(ground_offset.round())
	if key==_pose_key: return
	_pose_key=key
	feet=new_feet
	height=new_height
	position=ground_offset.round()
	var reach := 14.0
	for point in feet: reach=maxf(reach,absf(point)+6)
	width=clampf(reach,18,28)
	queue_redraw()

func _ellipse(center: Vector2, radii: Vector2, opacity: float, grid := 2) -> void:
	if opacity<0.015: return
	# Quantized falloff gives a soft edge without a blurry texture or solid disk.
	var left := int(floorf((center.x-radii.x)/grid))*grid
	var top := int(floorf((center.y-radii.y)/grid))*grid
	for y in range(top,int(ceilf(center.y+radii.y)),grid):
		for x in range(left,int(ceilf(center.x+radii.x)),grid):
			var q := (Vector2(x+grid*.5,y+grid*.5)-center)/radii
			var falloff := maxf(0,1-q.length_squared())
			var alpha := snappedf(opacity*falloff,0.025)
			if alpha>0.01:
				draw_rect(Rect2(x,y,grid,grid),Color(0.07,0.08,0.075,alpha))

func _draw() -> void:
	var air := clampf(height/MAX_HOP,0,1)
	var footprint_scale := lerpf(1.0,0.86,air)
	_ellipse(Vector2(0,0.5),Vector2(width,5.5)*footprint_scale,lerpf(.24,.11,air))
	var contact := clampf(1-height/4.0,0,1)
	for foot in feet:
		_ellipse(Vector2(foot,0),Vector2(5,2),.40*contact,1)
