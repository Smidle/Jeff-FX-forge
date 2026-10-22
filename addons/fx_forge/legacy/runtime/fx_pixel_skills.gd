@tool
extends RefCounted
## Original native-pixel choreography. Absolute-time sampling keeps seek/replay stable.
## Shapes use filled clusters, asymmetric silhouettes and separate attack/release beats.

static func draw(d: Node, p: float) -> void:
	match d._layer.procedural_motion:
		JeffForge3DLayer.ProceduralMotion.RETURN_BLADE: returning_blade(d, p)
		JeffForge3DLayer.ProceduralMotion.GROUND_WAVE: ground_wave(d, p)
		JeffForge3DLayer.ProceduralMotion.SWORD_ARRAY: sword_array(d, p)
		JeffForge3DLayer.ProceduralMotion.SPIRIT_BUTTERFLY: butterflies(d, p)
		JeffForge3DLayer.ProceduralMotion.ICE_CAGE: ice_cage(d, p)
		JeffForge3DLayer.ProceduralMotion.VOID_VORTEX: vortex(d, p)

static func line(d: Node, a: Vector2, b: Vector2, width: float, shade: int) -> void:
	d._line(a * (d._resolution-1), b * (d._resolution-1), maxi(1, roundi(width * clampi(d._layer.stroke_width,1,6) / 2.0)), d._palette[shade])

static func poly(d: Node, points: Array, shade: int) -> void:
	var scaled := PackedVector2Array()
	for point in points:
		scaled.append(point * (d._resolution-1))
	d._polygon(scaled, d._palette[shade])

static func dot(d: Node, at: Vector2, radius: Vector2, shade: int) -> void:
	d._ellipse(at * (d._resolution-1), radius * (d._resolution-1), d._palette[shade])

static func star(d: Node, center: Vector2, size: float, shade: int) -> void:
	line(d, center-Vector2(size,0), center+Vector2(size,0),1,shade)
	line(d, center-Vector2(0,size), center+Vector2(0,size),1,shade)

static func smooth(t: float) -> float:
	t = clampf(t,0,1)
	return t*t*(3-2*t)

static func envelope(p: float, attack: float=.1, release: float=.75) -> float:
	return smooth(p/attack) * (1-smooth((p-release)/(1-release)))

static func ribbon(d: Node, points: Array[Vector2], width: float, shade: int, bias: float=0.0) -> void:
	# Filled tapered ribbon, not a stack of constant-width outlines.
	var left: Array = []
	var right: Array = []
	var count: int = points.size()
	for i in count:
		var u: float = i/float(count-1)
		var direction: Vector2 = (points[mini(i+1,count-1)]-points[maxi(0,i-1)]).normalized()
		var normal := direction.orthogonal()
		var w: float = width * clampi(d._layer.stroke_width,1,6)/2.0 * pow(sin(u*PI),.72) * (.55+.45*u)
		left.append(points[i]+normal*w*(1+bias))
		right.push_front(points[i]-normal*w*(1-bias))
	poly(d,left+right,shade)

static func shard(d: Node, center: Vector2, angle: float, length: float, width: float, shade: int) -> void:
	var axis := Vector2.from_angle(angle)*length
	var side := axis.normalized().orthogonal()*width
	poly(d,[center-axis*.6-side*.3,center+axis,center+side,center-axis*.45+side*.45],shade)
	if length>.018:
		line(d,center-axis*.4,center+axis,1,mini(3,shade+1))

static func blade(d: Node, center: Vector2, angle: float, length: float) -> void:
	var axis := Vector2.from_angle(angle)
	var side := axis.orthogonal()
	var tip: Vector2 = center+axis*length
	var root: Vector2 = center-axis*length*.48
	poly(d,[tip,center+axis*length*.48+side*length*.16,root+side*length*.13,root-side*length*.13,center+axis*length*.48-side*length*.16],1)
	poly(d,[tip,root,root+side*length*.13,center+axis*length*.48+side*length*.16],2)
	line(d,root,tip,1,3)
	poly(d,[root-axis*length*.06-side*length*.30,root+axis*length*.07-side*length*.26,root+side*length*.06,root+axis*length*.07+side*length*.26,root-axis*length*.06+side*length*.30],2)
	line(d,root-axis*length*.09,root-axis*length*.38,2,0)
	line(d,root-axis*length*.34,root-axis*length*.41,1,2)

static func blade_point(d: Node, p: float, item: int) -> Vector2:
	var span: float = clampf(d._layer.skill_spread,.2,1)
	var travel: float = .5*(1-pow(1-clampf(p/.46,0,1),1.7)) if p<.46 else .5+.5*smooth((p-.46)/.54)
	var angle: float = travel*TAU
	var skew: float = (d._noise(item+71)-.5)*.07
	return Vector2(.5-cos(angle)*.36*span,.51-sin(angle)*(.24+skew)*span)

static func returning_blade(d: Node, p: float) -> void:
	for item in d._skill_count:
		var delay: float = .13*item/maxi(1,d._skill_count-1)
		var t: float = (p-delay)/(1-delay)
		if t<=0 or t>=1:
			continue
		var life: float = envelope(t,.065,.90)
		var points: Array[Vector2] = []
		for step in 25:
			points.append(blade_point(d,maxf(0,t-.18+step*.18/24),item))
		ribbon(d,points,.026*life,0,.2)
		ribbon(d,points,.012*life,1,.6)
		for segment in range(18,24):
			line(d,points[segment],points[segment+1],1,2)
		var head: Vector2 = blade_point(d,t,item)
		var direction: Vector2 = (blade_point(d,minf(1,t+.005),item)-blade_point(d,maxf(0,t-.005),item)).normalized()
		var angle: float = direction.angle()+sin(t*TAU*clampf(d._layer.skill_turns,.25,4))*.65
		var size: float = .10*life
		var shape: Array = []
		# Hooked steel edge and dark cut-out produce a readable returning weapon.
		for v in [Vector2(1,0),Vector2(.22,-.40),Vector2(-.58,-.34),Vector2(-.94,-.08),Vector2(-.45,-.02),Vector2(-.08,.09),Vector2(-.46,.41),Vector2(-.9,.51),Vector2(-.20,.53),Vector2(.4,.27)]:
			shape.append(head+v.rotated(angle)*size)
		poly(d,shape,1)
		poly(d,[head+Vector2(1,0).rotated(angle)*size,head+Vector2(.22,-.40).rotated(angle)*size,head+Vector2(-.58,-.34).rotated(angle)*size,head+Vector2(-.20,-.20).rotated(angle)*size],3)
		poly(d,[head+Vector2(-.08,.09).rotated(angle)*size,head+Vector2(-.46,.41).rotated(angle)*size,head+Vector2(-.20,.53).rotated(angle)*size,head+Vector2(.4,.27).rotated(angle)*size],2)
		for fleck in ceili(6*d._detail):
			var lag: float = .025+fleck*.021
			if t<lag:
				continue
			var at: Vector2 = blade_point(d,t-lag,item)+direction.orthogonal()*sin(fleck*2.4)*.025
			line(d,at,at-direction*.012*(1-fleck/7.0),1,1 if fleck>2 else 2)

static func dust_roll(d: Node, center: Vector2, radius: float, seed: float) -> void:
	if radius<.005:
		return
	var outline: Array = []
	for i in 14:
		var a: float = i/14.0*TAU
		var r: float = radius*(.85+.15*sin(i*2.7+seed*9))
		outline.append(center+Vector2(cos(a)*r*1.3,sin(a)*r))
	poly(d,outline,0)
	var crest: Array = []
	for i in 9:
		var a: float = PI+i/8.0*PI
		crest.append(center+Vector2(cos(a)*radius,sin(a)*radius*.7- radius*.15))
	crest.append(center+Vector2(radius*.4,radius*.1))
	crest.append(center+Vector2(-radius*.6,radius*.15))
	poly(d,crest,1)

static func ground_wave(d: Node, p: float) -> void:
	var span: float = clampf(d._layer.skill_spread,.2,1)
	# Separate impacts open an irregular fault. The blocks leave their own
	# origin and settle into dust; no repeated mirrored arrow shapes.
	for item in d._skill_count:
		var delay: float = .47*item/maxi(1,d._skill_count-1)
		var t: float = (p-delay)/.53
		if t<=0 or t>=1:
			continue
		var life: float = envelope(t,.06,.42)
		var center := Vector2(.18+.62*item/maxi(1,d._skill_count-1),.5+(d._noise(item+93)-.5)*.07)
		var open: float = sin(t*PI)*span
		poly(d,[center+Vector2(-.12,-.012*open),center+Vector2(-.04,-.050*open),center+Vector2(.02,-.02*open),center+Vector2(.09,0),center+Vector2(-.01,.047*open),center+Vector2(-.06,.014*open)],0)
		if t<.65:
			line(d,center-Vector2(.09,.004),center+Vector2(.06,0),1,2 if t<.16 else 1)
		for fragment in 6:
			var seed: float = d._noise(item*41+fragment+103)
			var side: float = -1 if fragment%2 else 1
			var reach: float = (.025+sin(t*PI*.6)*(.12+seed*.08))*span
			var at: Vector2 = center+Vector2(-.095+fragment*.033+(seed-.5)*.035,side*reach)
			var size: float = (.028+seed*.022)*life
			var rotation: float = (seed-.5)*1.5+side*t*.6
			if fragment<ceili(6*d._detail):
				dust_roll(d,at+Vector2(-.01,side*.025),(.037+seed*.019)*sin(t*PI)*life,seed)
			var shape: Array=[]
			for v in [Vector2(-1,-.4),Vector2(-.2,-1),Vector2(.8,-.55),Vector2(1,.45),Vector2(-.45,.65)]:
				shape.append(at+v.rotated(rotation)*size)
			poly(d,shape,0)
			poly(d,[shape[0],shape[1],shape[2],at],1)
			line(d,shape[0],shape[1],1,2)
			if t<.24:
				line(d,at,at-Vector2(.012,side*.025),1,2)
		# One ragged pressure front, appearing briefly before the dust mass.
		if t<.48:
			var crest: Array[Vector2]=[]
			for segment in 17:
				var u: float=segment/16.0
				var angle: float=-PI*.48+u*PI*.96
				var radius: float=(.035+.19*t)*span
				crest.append(center+Vector2(cos(angle)*radius*.65,sin(angle)*radius*(1+.10*sin(u*17+item))))
			ribbon(d,crest,.012*(1-t/.48),2)

static func sword_position(d: Node, p: float, item: int) -> Vector2:
	var span: float = clampf(d._layer.skill_spread,.2,1)
	var delay: float = .09*item/maxi(1,d._skill_count-1)
	var gather: float = smooth((p-delay)/.25)
	var release: float = smooth((p-.66-delay*.45)/.27)
	var angle: float = item/float(d._skill_count)*TAU+p*clampf(d._layer.skill_turns,.25,4)*1.4+d._noise(item+227)*.12
	return Vector2(.5+cos(angle)*(.25+.12*release)*span,.66-gather*.17+sin(angle)*.13*span-release*.13)

static func sword_array(d: Node, p: float) -> void:
	var life: float = envelope(p,.08,.84)
	# Back row is painted first. Upright blades have visible hilts and facets.
	for row in 2:
		for item in d._skill_count:
			var center: Vector2 = sword_position(d,p,item)
			if (center.y>.50)!=(row==1):
				continue
			var delay: float = .09*item/maxi(1,d._skill_count-1)
			var grow: float = smooth((p-delay)/.22)
			var release: float = smooth((p-.66-delay*.45)/.27)
			var angle: float = -PI*.5+(center.x-.5)*(.8+release*3)
			var length: float = .12*grow*life*(1-.2*release)
			if length<.005:
				continue
			var wake: Array[Vector2] = []
			for step in 16:
				var lag: float = (15-step)/15.0*.18
				wake.append(sword_position(d,maxf(0,p-lag),item)+Vector2(0,.10*(1-step/15.0)))
			ribbon(d,wake,.014*life,0)
			blade(d,center,angle,length)
			if d._detail>.25 and p>.22 and p<.7:
				star(d,center+Vector2.from_angle(angle)*length*.72,.014*(.5+.5*sin(p*13+item)),3)
	if d._detail>0:
		for mote in ceili(12*d._detail):
			var t: float = fposmod(p*1.4+d._noise(mote+279),1)
			var a: float = d._noise(mote+281)*TAU+p*2
			var at := Vector2(.5+cos(a)*.23*(1-t),.70-t*.35+sin(a)*.05)
			if t<.85 and life>.3:
				line(d,at,at+Vector2(.003,.013),1,1 if mote%3 else 2)

static func butterfly_point(d: Node, p: float, item: int) -> Vector2:
	var span: float = clampf(d._layer.skill_spread,.2,1)
	var seed: float = d._noise(item+331)
	var sweep: float = p*TAU*clampf(d._layer.skill_turns,.25,4)
	var lane: float = (item/float(maxi(1,d._skill_count-1))-.5)*.45*span
	return Vector2(.5+lane+sin(sweep+seed*TAU)*.085*span,.79-p*(.42+seed*.16)+sin(sweep*1.5+seed*8)*.045)

static func butterflies(d: Node, p: float) -> void:
	for item in d._skill_count:
		var delay: float = d._noise(item+349)*.10
		var t: float = (p-delay)/(1-delay)
		if t<=0 or t>=1:
			continue
		var center: Vector2 = butterfly_point(d,t,item)
		var life: float = envelope(t,.17,.76)
		var seed: float = d._noise(item+359)
		var flap: float = sin(t*TAU*(4+seed*2)+seed*8)
		var size: float = (.050+seed*.024)*life
		var tilt: float = cos(t*6+seed*8)*.30
		if size<.004:
			continue
		for side in [-1,1]:
			var open: float = .20+.80*absf(flap+side*.12)/1.12
			var fore: Array = []
			var inner: Array = []
			for v in [Vector2(.04,-.12),Vector2(.48,-.90),Vector2(.94,-1.12),Vector2(1.1,-.73),Vector2(1.05,-.24),Vector2(.59,.12),Vector2(.15,.14)]:
				fore.append(center+Vector2(v.x*side*open,v.y).rotated(tilt)*size)
			for v in [Vector2(.08,.02),Vector2(.56,-.65),Vector2(.87,-.82),Vector2(.88,-.29),Vector2(.36,-.01)]:
				inner.append(center+Vector2(v.x*side*open,v.y).rotated(tilt)*size)
			poly(d,fore,0)
			poly(d,inner,2)
			var hind: Array = []
			for v in [Vector2(.10,.03),Vector2(.69,.10),Vector2(.60,.49),Vector2(.35,.76),Vector2(.10,.38)]:
				hind.append(center+Vector2(v.x*side*open,v.y).rotated(tilt)*size)
			poly(d,hind,1)
			line(d,center,center+Vector2(side*open*.75,-.63).rotated(tilt)*size,1,1)
			if d._detail>.35:
				dot(d,center+Vector2(side*open*.82,-.62).rotated(tilt)*size,Vector2(.008,.008)*life,3)
		line(d,center+Vector2(0,-.35).rotated(tilt)*size,center+Vector2(0,.52).rotated(tilt)*size,1,0)
		line(d,center+Vector2(0,-.38).rotated(tilt)*size,center+Vector2(.12,-.58).rotated(tilt)*size,1,3)
		for mote in ceili(5*d._detail):
			var lag: float = .03*(mote+1)
			if t>lag and t<.87:
				var at: Vector2 = butterfly_point(d,t-lag,item)+Vector2(sin(mote*4+item)*.015,mote*.012)
				dot(d,at,Vector2.ONE*(.009 if mote==0 else .004)*life,2 if mote<2 else 1)

static func crystal(d: Node, root: Vector2, height: float, width: float, lean: float, shade: int=2) -> void:
	var tip: Vector2 = root+Vector2(lean,-height)
	var shoulder: Vector2 = root+Vector2(lean*.7,-height*.67)
	poly(d,[root-Vector2(width*.8,0),shoulder-Vector2(width*.7,0),tip,shoulder+Vector2(width,0),root+Vector2(width*.7,.01)],0)
	poly(d,[root,shoulder-Vector2(width*.7,0),tip,root+Vector2(width*.1,0)],1)
	poly(d,[root,tip,shoulder+Vector2(width,0),root+Vector2(width*.7,.01)],shade)
	line(d,shoulder-Vector2(width*.7,0),tip,1,3)
	line(d,tip,root+Vector2(width*.1,-height*.12),1,1)
	poly(d,[root+Vector2(-width*.2,-height*.22),root+Vector2(lean*.5,-height*.5),root+Vector2(width*.6,-height*.27)],1)

static func ice_cage(d: Node, p: float) -> void:
	var span: float = clampf(d._layer.skill_spread,.2,1)
	var decay: float = smooth((p-.70)/.30)
	# Frost creeps out from each root before growth. No wire-like top connectors.
	for row in 2:
		for item in d._skill_count:
			var angle: float = item/float(d._skill_count)*TAU+.25
			if (sin(angle)>0)!=(row==1):
				continue
			var seed: float = d._noise(item+419)
			var t: float = clampf((p-item/float(d._skill_count)*.11)/.30,0,1)
			var grow: float = 1-pow(1-t,3)
			var root := Vector2(.5+cos(angle)*.28*span,.75+sin(angle)*.10*span)
			var h: float = (.29+seed*.22)*grow
			var w: float = (.042+seed*.022)*span*grow
			var lean: float = -cos(angle)*(.055+seed*.07)*grow
			if grow<.02:
				continue
			for vein in ceili(3*d._detail):
				var direction := Vector2.from_angle(angle+vein*.9)
				var length: float = .065*grow*(1-decay)
				line(d,root,root+direction*length,1,1)
				line(d,root+direction*length*.55,root+direction.rotated(.6)*length*.8,1,2)
			var breakup: float = clampf((p-.70-seed*.06)/(.30-seed*.06),0,1)
			if breakup<=0:
				crystal(d,root,h,w,lean,2 if row else 1)
				if d._detail>.3:
					crystal(d,root+Vector2(w*.9,.008),h*.43,w*.43,lean*.5+.025,1)
				if p>.4:
					var crack: Vector2 = root+Vector2(lean*.5,-h*.52)
					line(d,crack-Vector2(w*.4,.014),crack+Vector2(w*.5,-.025),1,0)
				if p>.2 and p<.55 and d._detail>seed*.7:
					star(d,root+Vector2(lean,-h),.018*sin((p-.2)/.35*PI),3)
			else:
				# Each crystal breaks at a different instant. Unequal pieces inherit
				# its silhouette, then rotate and drift with distinct velocities.
				for part in ceili(2+2*d._detail):
					var random: float = d._noise(item*23+part+463)
					var q: float = (part+.35+random*.3)/(2+ceil(2*d._detail))
					var drift := Vector2(cos(angle)*(.06+random*.14)*breakup,-(.03+random*.08)*sin(breakup*PI)+breakup*breakup*.12)
					var at: Vector2 = root+Vector2(lean*q,-h*q)+drift
					var axis: float = -PI*.5+breakup*(random-.5)*4
					shard(d,at,axis,h*(.17+random*.07)*(1-breakup),w*(.55+random*.3)*(1-breakup),1 if part%2 else 2)

static func vortex(d: Node, p: float) -> void:
	var span: float = clampf(d._layer.skill_spread,.2,1)
	var life: float = envelope(p,.20,.70)
	var rotation: float = p*TAU*clampf(d._layer.skill_turns,.25,4)
	var center := Vector2(.5,.5)
	# Broken sheets of energy advect inward. Varying arm lengths, widths and
	# spacing leave a dark aperture rather than a symmetric pinwheel symbol.
	for arm in d._skill_count:
		var seed: float = d._noise(arm+521)
		var phase: float = arm/float(d._skill_count)*TAU+seed*.65
		for piece in 3:
			var drift: float = fposmod(p*(1.1+seed*.3)+piece/3.0+seed,1)
			var radius: float = (.095+(.31-drift*.25))*span*life
			var sweep: float = (1.2+seed*.65)*(1-.45*drift)
			var points: Array[Vector2] = []
			var width: float = (.032+.042*seed)*sin(drift*PI)*life
			for segment in 20:
				var u: float = segment/19.0
				var a: float = phase+rotation+piece*.8-u*sweep
				var r: float = radius*(1-.22*u)+sin(u*PI)*.01
				points.append(center+Vector2.from_angle(a)*r)
			ribbon(d,points,width,0,.4)
			ribbon(d,points,width*.55,1,-.4)
			if drift>.22 and drift<.85:
				ribbon(d,points,width*.15,2,-.6)
	# Irregular, short inner lip segments suggest depth without filling the void.
	for segment in 7:
		var seed: float = d._noise(segment+577)
		var a: float = segment/7.0*TAU+rotation*.55
		var radius: float = (.087+seed*.017)*span*life
		var pts: Array[Vector2] = []
		for step in 8:
			pts.append(center+Vector2.from_angle(a+step*.045)*radius)
		ribbon(d,pts,.009*life,1 if segment%3 else 2)
	for mote in ceili(22*d._detail):
		var seed: float = d._noise(mote+601)
		var t: float = fposmod(p*(1.1+seed*.4)+seed,1)
		var a: float = d._noise(mote+619)*TAU+rotation+t*.9
		var radius: float = (.10+.31*(1-t))*span*life
		var at: Vector2 = center+Vector2.from_angle(a)*radius
		if t<.94 and life>.15:
			shard(d,at,a+PI*.6,.013*(1-t)*life,.004,1 if mote%3 else 2)

static func flame(d: Node, elapsed: float) -> void:
	var cycle: float = fposmod(elapsed*clampf(d._layer.flame_speed,.2,3)/2,1)
	var wave: float = cycle*TAU
	var height: float = clampf(d._layer.flame_height,.4,1.1)*.72
	var width: float = clampf(d._layer.flame_width,.15,.65)
	var turbulence: float = clampf(d._layer.flame_turbulence,0,1)
	var lean: float = clampf(d._layer.flame_lean,-1,1)*.13
	var core: float = clampf(d._layer.flame_core,.25,.8)
	var seed: float = d._noise(173)*TAU
	# Build moving hot packets once per frame. They stretch on ascent and shrink
	# before wrapping below the live base, so no particle pops across the seam.
	var packets: Array[Vector4] = []
	for tongue in d._tongues:
		var side: float = 0 if tongue==0 else (-1 if tongue%2 else 1)
		for parcel in 3:
			var life: float = fposmod(cycle+parcel/3.0+d._noise(tongue+217)*.27,1)
			var rise: float = life*.96
			var x: float = .5+side*width*.30*(1-rise)+lean*rise+sin(rise*7-wave+seed+tongue)*width*.14*rise*turbulence
			var y: float = .88-height*rise*(1 if tongue==0 else .78)
			var radius: float = width*(.19 if tongue==0 else .15)*pow(sin(life*PI),.7)
			packets.append(Vector4(x,y,maxf(.001,radius),maxf(.001,height*.18*pow(sin(life*PI),.65))))
	var resolution: int = d._resolution
	var heat: Array[float] = d._flame_heat
	heat.fill(0.0)
	var top: int = maxi(1,floori((.88-height*1.12)*resolution))
	var bottom: int = mini(resolution-1,ceili(.91*resolution))
	var left: int = maxi(1,floori((.5-width*.65-absf(lean))*resolution))
	var right: int = mini(resolution-1,ceili((.5+width*.65+absf(lean))*resolution))
	for y in range(top,bottom):
		var u: float = (.88-(y+.5)/resolution)/height
		var lift: float = clampf(u,0,1)
		var shift: float = lean*lift+sin(lift*8-wave*2+seed)*width*.10*lift*turbulence
		var body_width: float = width*.40*pow(maxf(0,1-lift),.82)
		body_width *= 1+sin(lift*16-wave*3+seed)*.28*turbulence
		var strength: float = clampf((u+.035)*18,0,1)*clampf((.83-u)*7,0,1)*(1.0+core*.8)
		var fold: float = sin(u*17-wave*3+seed)*.24*turbulence*clampf(u*3,0,1)
		for x in range(left,right):
			var fx: float = (x+.5)/resolution
			var body: float = maxf(0,1-absf(fx-.5-shift)/maxf(.001,body_width))
			heat[y*resolution+x] = body*strength+sin((fx-.5)*32+u*9-wave*2+seed)*fold
	for packet in packets:
		var x0: int = maxi(left,floori((packet.x-packet.z)*resolution))
		var x1: int = mini(right,ceili((packet.x+packet.z)*resolution))
		var y0: int = maxi(top,floori((packet.y-packet.w)*resolution))
		var y1: int = mini(bottom,ceili((packet.y+packet.w)*resolution))
		for y in range(y0,y1):
			var dy: float = ((y+.5)/resolution-packet.y)/packet.w
			for x in range(x0,x1):
				var dx: float = ((x+.5)/resolution-packet.x)/packet.z
				var value: float = maxf(0,1-dx*dx-dy*dy)
				heat[y*resolution+x] += value*value*.85
	for y in range(top,bottom):
		if (.88-(y+.5)/resolution)/height<-.02:
			continue
		for x in range(left,right):
			var value: float = heat[y*resolution+x]
			if value<.30:
				continue
			var shade: int = 0 if value<.53 else (1 if value<.88 else (2 if value<1.4+(.65-core) else 3))
			d.pixels.set_pixel(x,y,d._palette[shade])

	for ember in d._embers:
		var life: float = fposmod(cycle+float(ember)/maxi(1,d._embers)+d._noise(ember+301),1)
		var strength: float = sin(life*PI)
		var x: float = .5+lean*(.6+life)+sin(life*PI+d._noise(ember+337)*TAU)*width*.28
		var y: float = .86-height*(.45+life*.65)
		if strength>.25:
			line(d,Vector2(x,y),Vector2(x+.003,y+.014*strength),1,2 if life<.55 else 1)
