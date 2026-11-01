@tool
extends RefCounted
## Original four-color pixel drawing. No sprite atlas or image input.
var image: Image
var palette: Array[Color]=[]
## 剑用的固定颜色（只略带主色），和气色的拖尾区分开：
## 0 描边 1 钢暗面 2 钢亮面 3 刃光 4 暗金 5 亮金 6 缠绳
var steel: Array[Color]=[]
var size: int=64
## 不随时间变化的部分（剑身、冰箭和描边）只画一次，之后每帧复制再叠加动态细节
var _base: Image
var _base_style: int=-1

func _init(resolution: int=64) -> void:
	size=resolution
	image=Image.create(size,size,false,Image.FORMAT_RGBA8)

func colors(primary: Color, secondary: Color, saturation: float) -> void:
	palette=[secondary.darkened(.5),secondary,primary,primary.lerp(Color.WHITE,.68)]
	for i in 4:
		var c: Color=palette[i]
		palette[i]=Color.from_hsv(c.h,clampf(c.s*saturation,0,1),c.v,1)
	var tint: Color=palette[2]
	steel=[Color(.06,.08,.12).lerp(tint,.05),Color(.40,.46,.53).lerp(tint,.12),Color(.73,.79,.84).lerp(tint,.1),Color(.97,.99,1),
		Color(.50,.31,.11),Color(.95,.74,.30),Color(.22,.14,.10)]

func put(x: int, y: int, color: Color) -> void:
	if x>=0 and y>=0 and x<size and y<size: image.set_pixel(x,y,color)

func _empty(x: int, y: int) -> bool:
	return x<0 or y<0 or x>=size or y>=size or image.get_pixel(x,y).a<.5

## 1 像素描边：紧挨着图形的透明像素涂成描边色
func outline(color: Color) -> void:
	var edge: Array[Vector2i]=[]
	for y in size:
		for x in size:
			if _empty(x,y) and (not _empty(x-1,y) or not _empty(x+1,y) or not _empty(x,y-1) or not _empty(x,y+1)):
				edge.append(Vector2i(x,y))
	for p in edge: image.set_pixelv(p,color)

## 边缘闪动：每帧在图形外缘随机点亮几个像素。抽样而不是逐像素扫描，64 像素下也很便宜。
func edge_flicker(color: Color, count: int, frame: int, area: Rect2) -> void:
	for i in count:
		var x: int=int(lerpf(area.position.x,area.end.x,fposmod(sin(float(frame*131+i*17))*43758.5453,1))*size)
		var y: int=int(lerpf(area.position.y,area.end.y,fposmod(sin(float(frame*71+i*29+7))*24634.6345,1))*size)
		if _empty(x,y) and (not _empty(x-1,y) or not _empty(x+1,y) or not _empty(x,y-1) or not _empty(x,y+1)):
			image.set_pixel(x,y,color)

## 静态部分画一次后缓存；返回 true 表示这次是新画的
func _static(style: int) -> bool:
	if _base!=null and _base_style==style:
		image.copy_from(_base)
		return false
	image.fill(Color.TRANSPARENT)
	return true

func _keep(style: int) -> void:
	_base=image.duplicate() as Image
	_base_style=style

func polygon(points: Array, ink: int) -> void:
	# Small crystal fragments often occupy only two rows; skip the empty scanlines.
	var top: float=float(size)
	var bottom: float=0
	for point in points:
		top=minf(top,point.y*size)
		bottom=maxf(bottom,point.y*size)
	for y in range(maxi(1,ceili(top-.5)),mini(size-1,ceili(bottom-.5))):
		var crossings: Array[float]=[]
		for i in points.size():
			var a: Vector2=points[i]*size
			var b: Vector2=points[(i+1)%points.size()]*size
			if (a.y<=y+.5 and b.y>y+.5) or (b.y<=y+.5 and a.y>y+.5):
				crossings.append(a.x+(y+.5-a.y)*(b.x-a.x)/(b.y-a.y))
		crossings.sort()
		for i in range(0,crossings.size()-1,2):
			for x in range(maxi(1,ceili(crossings[i]-.5)),mini(size-1,ceili(crossings[i+1]-.5))):
				image.set_pixel(x,y,palette[ink])

func line(a: Vector2, b: Vector2, width: float, ink: int) -> void:
	var delta: Vector2=(b-a)*size
	var steps: int=maxi(1,ceili(maxf(absf(delta.x),absf(delta.y))))
	for step in steps+1:
		var p: Vector2=(a+(b-a)*step/float(steps))*size
		var radius: int=maxi(0,roundi(width*size*.5)-1)
		for y in range(maxi(1,roundi(p.y)-radius),mini(size-1,roundi(p.y)+radius+1)):
			for x in range(maxi(1,roundi(p.x)-radius),mini(size-1,roundi(p.x)+radius+1)):
				image.set_pixel(x,y,palette[ink])

func ellipse(center: Vector2, radius: Vector2, ink: int) -> void:
	var c: Vector2=center*size
	var r: Vector2=radius*size
	if minf(r.x,r.y)<.5: return
	for y in range(maxi(1,ceili(c.y-r.y)),mini(size-1,ceili(c.y+r.y))):
		var dy: float=(y+.5-c.y)/r.y
		var reach: float=r.x*sqrt(maxf(0,1-dy*dy))
		for x in range(maxi(1,ceili(c.x-reach-.5)),mini(size-1,ceili(c.x+reach-.5))):
			image.set_pixel(x,y,palette[ink])

func head(style: int, t: float, deformation: float, halo: float) -> void:
	match style:
		1: fireball(t,deformation,halo)
		2: ice_arrow(t,deformation,halo)
		3: shadow_arrow(t,deformation,halo)
		_: sword(t,deformation,halo)

func fireball(t: float, deformation: float, halo: float) -> void:
	image.fill(Color.TRANSPARENT)
	var flow: float=t*5.5
	# Coherent rotating folds: each contour shares the same phase, never frame noise.
	for band in 4:
		var points: Array=[]
		var radius: float=[.225,.193,.147,.085][band]
		var center:=Vector2(.71+band*.014,.5-band*.012)
		var steps: int=[20,16,12,12][band]
		for j in steps:
			var angle: float=j*TAU/float(steps)
			var fold: float=1+deformation*(.11*sin(angle*3-flow)+.06*sin(angle*5+flow*.7))
			var back: float=maxf(0,-cos(angle))
			var x: float=center.x+cos(angle)*radius*fold-back*back*(.12 if band<2 else .035)
			points.append(Vector2(minf(.94,x),center.y+sin(angle)*radius*fold))
		polygon(points,band)
	# The hottest surface bends around the core; darker channels suggest volume.
	for fold in 2:
		var points: Array=[]
		for j in 9:
			var angle: float=-.7+j*.24+flow*.35+fold*PI
			var r: float=.11+j*.003
			points.append(Vector2(.73,.49)+Vector2(cos(angle)*r,sin(angle)*r*.85))
		for j in range(1,points.size()): line(points[j-1],points[j],.02,1 if fold==0 else 2)
	for i in 3:
		var y: float=.5+(i-1)*.09
		var curl: float=sin(flow+i*2)*.035*deformation
		polygon([Vector2(.64,y),Vector2(.44,y-.045+curl),Vector2(.20+i*.045,y-.075+curl),Vector2(.36,y+.008),Vector2(.53,y+.055)],1 if i!=1 else 2)
	line(Vector2(.84,.425),Vector2(.89,.47),.019,3)
	if halo>.01:
		for i in 3:
			var phase: float=fposmod(t*.75+i*.31,1)
			var at:=Vector2(.34-phase*.22,.5+sin(i*2.8+t*3)*(.15+halo*.04))
			line(at,at+Vector2(.025*(1-phase),-.01),.018,2 if phase<.5 else 1)

func ice_arrow(t: float, deformation: float, halo: float) -> void:
	# 按像素画：菱形冰晶箭头、亮色中脊、细箭杆和后方两片冰翎，深色描边。
	var n: int=size
	var cy: int=n/2
	var tip: int=int(n*.94)
	var head_length: int=maxi(4,roundi(n*.27))
	var start: int=tip-head_length
	if _static(2):
		var half: int=maxi(2,roundi(n*.075))
		var peak: int=tip-roundi(head_length*.55)
		for x in range(start,tip+1):
			var h: int=roundi(half*float(tip-x)/maxf(1,tip-peak)) if x>=peak else roundi(half*(1.0-.5*float(peak-x)/maxf(1,peak-start)))
			for dy in range(-h,h+1): put(x,cy+dy,palette[3] if dy==0 else (palette[2] if dy<0 else palette[1]))
		var back: int=roundi(n*.14)
		var shaft: int=roundi(n*.012)
		for x in range(back,start):
			for dy in range(-shaft,shaft+1): put(x,cy+dy,palette[2] if dy<=0 else palette[1])
		var fin_height: int=maxi(2,roundi(n*.085))
		var fin_length: int=maxi(3,roundi(n*.12))
		for i in range(1,fin_length+1):
			var y: int=roundi(fin_height*float(i)/fin_length)
			for x in [back+fin_length-i,back+fin_length-i+1]:
				put(x,cy-y,palette[2]); put(x,cy+y,palette[1])
		outline(palette[0])
		_keep(2)
	# 一道高光沿箭杆扫到箭尖；箭头附近冰屑闪烁
	var at: int=roundi(n*.14)+int(fposmod(t*1.3,1.0)*(tip-roundi(n*.14)+6))-3
	for x in range(at,at+maxi(2,n/16)):
		if x<tip and not _empty(x,cy): put(x,cy,Color.WHITE if x>=start else palette[3])
	if halo>.01:
		edge_flicker(palette[3],maxi(2,n/10),int(t*24),Rect2(float(start)/n,.38,.98-float(start)/n,.24))

func shadow_arrow(t: float, deformation: float, halo: float) -> void:
	image.fill(Color.TRANSPARENT)
	var wave: float=sin(t*4)*.018*deformation
	# Solid obsidian body, a shaded belly and broken amethyst bevels, not an outline icon.
	polygon([Vector2(.94,.5),Vector2(.68,.361),Vector2(.51,.403),Vector2(.36,.447+wave),Vector2(.15,.463),Vector2(.28,.524),Vector2(.50,.582),Vector2(.70,.601)],0)
	polygon([Vector2(.94,.5),Vector2(.68,.377),Vector2(.54,.425),Vector2(.36,.466+wave),Vector2(.65,.481)],1)
	polygon([Vector2(.94,.5),Vector2(.65,.481),Vector2(.46,.505),Vector2(.68,.567)],0)
	polygon([Vector2(.94,.5),Vector2(.73,.555),Vector2(.63,.561),Vector2(.69,.583)],1)
	polygon([Vector2(.92,.5),Vector2(.68,.395),Vector2(.60,.414),Vector2(.73,.433)],2)
	polygon([Vector2(.92,.5),Vector2(.65,.475),Vector2(.48,.494),Vector2(.70,.508)],2)
	line(Vector2(.72,.487),Vector2(.91,.5),.018,3)
	line(Vector2(.60,.414),Vector2(.52,.446),.018,2)
	line(Vector2(.62,.559),Vector2(.72,.575),.018,2)
	polygon([Vector2(.55,.454),Vector2(.35,.419+wave),Vector2(.19,.38),Vector2(.28,.452),Vector2(.42,.478)],1)
	polygon([Vector2(.53,.534),Vector2(.35,.56+wave),Vector2(.18,.615),Vector2(.28,.539),Vector2(.44,.51)],0)
	if halo>.01:
		line(Vector2(.27,.436+wave),Vector2(.38,.455),.018,1)
		line(Vector2(.25,.569),Vector2(.39,.54+wave),.018,1)
		# 边缘暗焰：每帧在外缘随机亮起几个像素
		edge_flicker(palette[1],maxi(3,size/6),int(t*24),Rect2(.14,.34,.82,.32))

func fire_impact(p: float, fragments: int, seed: int) -> void:
	var growth: float=sin(minf(1,p*2.5)*PI*.5)
	var radius: float=(.12+.22*growth)*pow(1-p,.65)
	# Overlapping lobes roll outwards, then cool to isolated embers.
	for i in 7:
		var a: float=i/7.0*TAU+.2
		var center:=Vector2(.5,.5)+Vector2.from_angle(a)*radius*.53
		var r: float=radius*(.65+.12*sin(i*3+p*6))
		if p>.6 and i%2==0: continue
		ellipse(center,Vector2(r,r*.8),0 if p>.5 else 1)
		if p<.62: ellipse(center-Vector2.from_angle(a)*r*.2,Vector2(r*.7,r*.57),1 if p>.3 else 2)
	if p<.4: ellipse(Vector2(.5,.5),Vector2.ONE*radius*(1-p*2),3 if p<.14 else 2)
	for i in clampi(fragments,0,24):
		var random: float=fposmod(sin((seed+i*93)*.71)*43758.54,1)
		var d:=Vector2.from_angle(i*2.399+random*.5)
		var c:=Vector2(.5,.5)+d*(.08+sqrt(p)*(.25+random*.1))+Vector2(0,p*p*.07)
		line(c-d*.04*(1-p),c,.018,2 if p<.5 else 1)

func shadow_impact(p: float, fragments: int, seed: int) -> void:
	var radius: float=(.17+minf(1,p*5)*.18)*pow(1-p,.8)
	if p<.7: ellipse(Vector2(.5,.5),Vector2(radius*.75,radius*.61),0)
	for i in 32:
		if i%8>4: continue
		var a: float=i/32.0*TAU+p*1.6
		var b: float=(i+1)/32.0*TAU+p*1.6
		line(Vector2(.5,.5)+Vector2.from_angle(a)*radius,Vector2(.5,.5)+Vector2.from_angle(b)*radius,.022,2 if p<.4 else 1)
	for i in clampi(fragments,0,24):
		var random: float=fposmod(sin((seed+i*113)*.37)*43758.54,1)
		var angle: float=i*2.399+p*2+random
		var c:=Vector2(.5,.5)+Vector2.from_angle(angle)*(.15+random*.27)*(1-p)
		line(c,c-Vector2.from_angle(angle+.6)*.06*(1-p),.018,2 if i%3 else 3)
	if p<.18: line(Vector2(.44,.5),Vector2(.56,.5),.018,3)

func sword(t: float, deformation: float, halo: float) -> void:
	# 按像素画，24 像素和 64 像素下都看得出剑：钢色剑身（亮面、刃光、暗面）收成剑尖，
	# 比剑身宽得多的金色剑格，缠绳剑柄和剑首，深色描边。钢色固定，不跟拖尾的气色混在一起。
	var n: int=size
	var cy: int=n/2
	var tip: int=int(n*.94)
	var blade: int=roundi(n*.33)
	var guard: int=roundi(n*.26)
	var pommel: int=roundi(n*.09)
	var half: int=maxi(1,roundi(n*.032))
	if _static(0):
		var taper: int=maxi(2,roundi(n*.1))
		for x in range(blade,tip+1):
			var reach: int=mini(half,int(float(tip-x)*half/taper))
			for dy in range(-reach,reach+1): put(x,cy+dy,steel[3] if dy==0 else (steel[2] if dy<0 else steel[1]))
		var guard_half: int=maxi(3,roundi(n*.12))
		for dy in range(-guard_half,guard_half+1):
			# 剑格两端略向剑柄方向弯
			var swept: int=1 if absi(dy)==guard_half else 0
			for x in range(guard-swept,blade-swept): put(x,cy+dy,steel[5] if dy<0 else steel[4])
		var grip: int=roundi(n*.135)
		var grip_half: int=roundi(n*.012)
		for x in range(grip,guard):
			for dy in range(-grip_half,grip_half+1): put(x,cy+dy,steel[4] if (x+dy)%2==0 else steel[6])
		var pommel_half: int=maxi(1,roundi(n*.03))
		for x in range(pommel,grip):
			for dy in range(-pommel_half,pommel_half+1): put(x,cy+dy,steel[5] if dy<=0 else steel[4])
		outline(steel[0])
		_keep(0)
	# 一道高光沿剑身从剑格扫到剑尖
	var at: int=blade+int(fposmod(t*1.5,1.0)*(tip-blade+6))-3
	for x in range(at,at+maxi(2,n/16)):
		if x>=blade and x<tip:
			for dy in range(-half,0): put(x,cy+dy,steel[3])
	# 剑气：剑身两侧描边外随机闪出气色像素
	if halo>.01:
		var frame: int=int(t*24)
		for x in range(blade,tip-1):
			for side in [-1,1]:
				if fposmod(sin(float(x*37+frame*11+side*5))*43758.5453,1)<halo*.55 and _empty(x,cy+side*(half+2)):
					put(x,cy+side*(half+2),palette[2] if (x+frame)%3 else palette[3])
	# 剑穗：从剑首往后飘，随时间摆动
	var sway: float=(sin(t*9.0)*.5+sin(t*5.3+1.0)*.5)*maxf(1,n*.04)*(.5+deformation)
	var tassel: int=maxi(2,pommel)
	for i in range(1,tassel+1):
		put(pommel-i,cy+roundi(sway*float(i)/tassel),palette[2] if i<tassel else palette[3])

func impact(p: float, style: int, fragments: int, seed: int) -> void:
	image.fill(Color.TRANSPARENT)
	if p<0 or p>=1: return
	if style==3:
		fire_impact(p,fragments,seed)
		return
	if style==5:
		shadow_impact(p,fragments,seed)
		return
	var core: float=pow(1-p,2)*.18
	if p<.35:
		if style==2:
			# Contact is a tiny bright cross, not a white disc hiding the blade tip.
			line(Vector2(.5-core*.7,.5),Vector2(.5+core*.7,.5),.018,3)
			line(Vector2(.5,.5-core*.48),Vector2(.5,.5+core*.48),.018,3)
		else:
			polygon([Vector2(.5-core,.5),Vector2(.49,.5-core*1.3),Vector2(.5+core,.5),Vector2(.51,.5+core)],3)
	var count: int=clampi(fragments,0,24)
	for i in count:
		var random: float=fposmod(sin((seed+i*127)*.43)*43758.54,1)
		var a: float=i/float(maxi(1,count))*TAU+random*.6
		var direction:=Vector2.from_angle(a)
		var radius: float=.06+sqrt(p)*(.22+random*.14)
		var center:=Vector2(.5,.5)+direction*radius
		var length: float=(.045+random*.035)*pow(1-p,1.2)
		if style==4:
			var side: Vector2=direction.orthogonal()*length*.45
			polygon([center+direction*length,center+side,center-direction*length*.7,center-side],2 if i%2 else 1)
		else:
			line(center-direction*length,center+direction*length*.2,.018 if style!=3 else .035,2 if p<.5 else 1)
	if style in [1,2,3]:
		var radius: float=.06+sqrt(p)*.31
		for i in 40:
			if i%5==0 or (p>.55 and i%3==0): continue
			if style==2 and (i%10>5 or p>.7): continue
			var a: float=i/40.0*TAU
			var b: float=(i+1)/40.0*TAU
			line(Vector2(.5,.5)+Vector2.from_angle(a)*radius,Vector2(.5,.5)+Vector2.from_angle(b)*radius,.02 if style!=3 else .045,1 if p>.35 else 2)
