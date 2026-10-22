@tool
extends RefCounted
## Original four-color pixel drawing. No sprite atlas or image input.
var image: Image
var palette: Array[Color]=[]
var size: int=64

func _init(resolution: int=64) -> void:
	size=resolution
	image=Image.create(size,size,false,Image.FORMAT_RGBA8)

func colors(primary: Color, secondary: Color, saturation: float) -> void:
	palette=[secondary.darkened(.5),secondary,primary,primary.lerp(Color.WHITE,.68)]
	for i in 4:
		var c: Color=palette[i]
		palette[i]=Color.from_hsv(c.h,clampf(c.s*saturation,0,1),c.v,1)

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
	image.fill(Color.TRANSPARENT)
	# Long needle crystal: offset facets, chipped shoulders and a bright internal ridge.
	polygon([Vector2(.94,.5),Vector2(.63,.397),Vector2(.43,.431),Vector2(.29,.456),Vector2(.18,.49),Vector2(.30,.542),Vector2(.51,.578),Vector2(.70,.555)],0)
	polygon([Vector2(.94,.5),Vector2(.63,.413),Vector2(.43,.447),Vector2(.25,.49),Vector2(.64,.485)],2)
	polygon([Vector2(.94,.5),Vector2(.25,.49),Vector2(.44,.536),Vector2(.69,.543)],1)
	polygon([Vector2(.94,.5),Vector2(.65,.478),Vector2(.38,.485),Vector2(.27,.498),Vector2(.63,.509)],3)
	polygon([Vector2(.63,.414),Vector2(.60,.473),Vector2(.43,.448)],1)
	polygon([Vector2(.65,.518),Vector2(.69,.541),Vector2(.82,.519)],2)
	polygon([Vector2(.47,.456),Vector2(.33,.407),Vector2(.19,.433),Vector2(.30,.488)],1)
	polygon([Vector2(.43,.455),Vector2(.33,.423),Vector2(.23,.437),Vector2(.32,.467)],2)
	polygon([Vector2(.44,.53),Vector2(.29,.566),Vector2(.21,.553),Vector2(.32,.513)],1)
	line(Vector2(.65,.416),Vector2(.90,.491),.018,3)
	line(Vector2(.46,.532),Vector2(.60,.549),.018,2)
	var glint: float=.35+fposmod(t*.44,1)*.43
	line(Vector2(glint,.474),Vector2(glint+.035,.487),.018,3)
	if halo>.01:
		var pulse: float=sin(t*3)*.015*deformation
		line(Vector2(.33,.58+pulse),Vector2(.44,.563),.018,1)

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
	image.fill(Color.TRANSPARENT)
	# A restrained sheath of qi. The steel silhouette stays rigid while its wisps move.
	if halo>.01:
		for side in [-1,1]:
			var wave: float=sin(t*5+side)*.022*deformation
			var edge: float=.065+clampf(halo,0,1)*.075
			polygon([Vector2(.13,.5+side*edge),Vector2(.42,.5+side*(edge+wave)),Vector2(.82,.5+side*.022),Vector2(.39,.5+side*.05)],1 if halo>.45 else 0)
	# Long double-edged jian: tapered tip, bevels and a narrow illuminated ridge.
	polygon([Vector2(.94,.5),Vector2(.79,.462),Vector2(.37,.432),Vector2(.29,.474),Vector2(.29,.526),Vector2(.37,.568),Vector2(.79,.538)],0)
	polygon([Vector2(.94,.5),Vector2(.78,.477),Vector2(.38,.450),Vector2(.32,.482),Vector2(.32,.5)],2)
	polygon([Vector2(.94,.5),Vector2(.32,.5),Vector2(.33,.524),Vector2(.38,.548),Vector2(.78,.521)],1)
	line(Vector2(.36,.49),Vector2(.88,.49),.018,3)
	line(Vector2(.40,.52),Vector2(.74,.52),.018,2)
	# Small swept guard leaves the blade, grip and pommel readable at game scale.
	polygon([Vector2(.33,.477),Vector2(.29,.405),Vector2(.23,.392),Vector2(.25,.447),Vector2(.29,.5),Vector2(.25,.553),Vector2(.23,.608),Vector2(.29,.595),Vector2(.33,.523)],0)
	polygon([Vector2(.32,.48),Vector2(.28,.421),Vector2(.25,.416),Vector2(.28,.474),Vector2(.28,.526),Vector2(.25,.584),Vector2(.28,.579),Vector2(.32,.52)],2)
	line(Vector2(.27,.43),Vector2(.29,.47),.018,3)
	line(Vector2(.27,.57),Vector2(.29,.53),.018,1)
	line(Vector2(.11,.5),Vector2(.28,.5),.062,0)
	line(Vector2(.12,.49),Vector2(.27,.49),.024,1)
	for x in [.15,.20,.25]: line(Vector2(x,.48),Vector2(x,.52),.018,2)
	polygon([Vector2(.065,.5),Vector2(.10,.47),Vector2(.14,.5),Vector2(.10,.53)],1)
	line(Vector2(.09,.49),Vector2(.11,.49),.018,3)
	# A travelling one-pixel glint, not a whole-blade flash.
	var glint: float=.39+fposmod(t*.35,1)*.35
	line(Vector2(glint,.47),Vector2(glint+.022,.49),.018,3)

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
