shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 dark_color : source_color;
uniform vec4 mid_color : source_color;
uniform vec4 light_color : source_color;
uniform vec4 hot_color : source_color;
uniform float width = 0.14;
uniform float head_width = 1.0;
uniform float tip_width = 0.0;
uniform float taper = 0.8;
uniform float density = 64.0;
uniform float trail_length = 1.0;
uniform float body_start = 0.7;
uniform float neck_width = 0.03;
uniform float release = 0.0;
uniform float opacity = 1.0;
uniform float brightness = 1.0;
uniform float color_mix = 0.7;
uniform float turbulence = 0.02;
uniform float effect_time = 0.0;
uniform int trail_style = 0;
uniform int head_element = 0;
uniform float ornament = 0.;
uniform float orbit_speed = 1.;
void vertex() {
 vec3 tangent = normalize(COLOR.rgb * 2.0 - 1.0);
 vec3 side = cross(INV_VIEW_MATRIX[2].xyz, tangent);
 if (length(side) < 0.001) { side = cross(vec3(0.,1.,0.),tangent); }
 if (length(side) < 0.001) { side = vec3(1.,0.,0.); }
 VERTEX += normalize(side) * (UV.y-.5) * (width*max(1.,head_width) + turbulence*2.0);
}
void fragment() {
 float cells=max(1.,trail_length*density);
 float along=min(1.,(floor(UV.x*cells)+.5)/cells);
 float extent=width*max(1.,head_width)+turbulence*2.;
 float across_cells=max(3.,ceil(extent*density));
 // Use an odd number of rows, so even a very fine trail has a centre pixel.
 across_cells=floor(across_cells*.5)*2.+1.;
 float across=((floor(UV.y*across_cells)+.5)/across_cells-.5)*extent;
 float u=clamp(along/max(.0001,body_start),0.,1.);
 float under_blade=clamp((along-body_start)/max(.0001,1.-body_start),0.,1.);
 float wave=sin(u*11.-effect_time*3.)*turbulence*sin(u*3.14159)*(1.-u);
 float radius=width*.5*mix(tip_width,head_width,pow(u,taper));
 // A broad flowing middle meets a narrow grip. The energy spine continues
 // underneath the blade to the contact point, even after the steel is gone.
 radius=mix(radius,neck_width*.5,smoothstep(head_element==0 ? .62 : .84,1.,u));
 radius*=pow(1.-under_blade,.65);
 if (trail_style==1) { radius*=.42; }
 if (trail_style==3) {
  radius*=.75+.25*sin(u*19.-effect_time*6.);
  wave+=sin(u*12.-effect_time*4.)*radius*.4*(1.-u);
 }
 if (trail_style==4) { radius*=.55; }
 if (trail_style==5) {
  radius*=.7+.3*sin(u*16.-effect_time*3.);
  wave+=sin(u*13.-effect_time*3.)*radius*.35*(1.-u);
 }
 float cutoff=pow(release,.85);
 if (along<cutoff || opacity<.01 || release>=1.) { discard; }
 float erosion=smoothstep(cutoff,cutoff+.065,along);
 radius*=erosion*(1.-release*.65);
 float shape=abs(across-wave);
 if(trail_style==5){radius*=1.+.2*sin(u*29.+effect_time*2.);}
 // A single-cell core survives shrinking; no alpha staircase or detached cap.
 radius=max(radius,extent/across_cells*.51*erosion*(1.-under_blade));
 bool strand=false;
 if (trail_style==0 && u<.86 && release<.65) {
  float flank=radius+width*(.15+.12*sin(u*9.+effect_time*2.))*sin(u*3.14159);
  strand=abs(shape-flank)<extent/across_cells*.48 && sin(u*24.-effect_time*4.)>.25 && u>.12;
 }
 if (trail_style==4 && u<.83 && u>.15 && release<.6) {
  float chip=mod(floor(u*43.),7.);
  strand=chip<1. && shape<radius+width*.20 && shape>radius+width*.08;
 }
 if (trail_style==5 && u<.85 && release<.75) {
  float curl=radius+width*.2*sin(u*3.14159);
  strand=abs(shape-curl)<extent/across_cells*.7 && sin(u*19.-effect_time*3.)>.05;
 }
 float orbit=sin(u*18.-effect_time*orbit_speed*4.)*width*.42*sin(u*3.14159);
 bool magical=trail_style>=3 && ornament>.01 && u<.95 && under_blade<=0. && release<.85;
 bool ribbon=magical && abs(across-wave-orbit)<extent/across_cells*.6;
 if(magical && trail_style==3 && shape<radius && u<.65 && sin(u*33.-effect_time*8.+across*90.)>.55){
  radius*=.45;
 }
 if(trail_style==5 && u<.4 && sin(u*57.+across*117.)>.5){radius*=.45;}
 if (shape>radius && !strand && !ribbon) { discard; }
 if (trail_style==2 && mod(floor(u*32.),4.)>0. && under_blade<=0.) { discard; }
 float value=1.-shape/max(radius,.0001);
 vec3 shade=value>.88 ? light_color.rgb : (value>.40 ? mid_color.rgb : dark_color.rgb);
 if (value>.95 && sin(u*18.-effect_time*5.)>.25 && u>.3) { shade=hot_color.rgb; }
 if (u<color_mix*.5) { shade=value>.65 ? mid_color.rgb : dark_color.rgb; }
 if (strand) { shade=mid_color.rgb; }
 if (trail_style==3 && value>.5 && sin(u*26.-effect_time*9.)>.4) { shade=light_color.rgb; }
 if (trail_style==4 && strand) { shade=light_color.rgb; }
 if (trail_style==5) {
  shade=value>.65 ? dark_color.rgb : (value>.30 ? mid_color.rgb : light_color.rgb);
  if (strand || u<.25) { shade=dark_color.rgb; }
 }
 if(ribbon){shade=trail_style==5 ? mid_color.rgb : light_color.rgb;}
 if (under_blade>0.) { shade=head_element==3 ? mid_color.rgb : light_color.rgb; }
 if (release>.45) { shade=mix(shade,mid_color.rgb,smoothstep(.45,1.,release)*.7); }
 ALBEDO=shade*brightness;
 ALPHA=opacity*(1.-smoothstep(.88,1.,release));
}
