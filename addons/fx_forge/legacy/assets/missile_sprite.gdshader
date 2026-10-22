shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D pixels : source_color, filter_nearest, repeat_disable;
uniform vec3 direction = vec3(1.,0.,0.);
uniform float size = 1.;
uniform float aspect = 1.;
uniform float rotation = 0.;
uniform float brightness = 1.;
uniform float opacity = 1.;
uniform int facing = 0;
uniform float dissolve = 0.;
uniform int element = 0;
uniform float contact = 0.;
uniform float pixel_density = 64.;
uniform vec4 hot_color : source_color = vec4(.88,1.,.97,1.);
void vertex() {
 vec3 x = INV_VIEW_MATRIX[0].xyz;
 vec3 y = INV_VIEW_MATRIX[1].xyz;
 vec3 z = INV_VIEW_MATRIX[2].xyz;
 if (facing == 1) { x=vec3(1.,0.,0.); y=vec3(0.,0.,-1.); z=vec3(0.,1.,0.); }
 if (facing == 2) {
  z=normalize(direction); x=cross(vec3(0.,1.,0.),z);
  if (length(x)<.001) { x=vec3(1.,0.,0.); }
  x=normalize(x); y=normalize(cross(z,x));
 }
 float a=rotation;
 if (facing == 3) {
  // The blade has real world length along its flight axis. A billboard rotation
  // alone overhangs the contact point when the camera sees a steep trajectory.
  x=normalize(direction); y=cross(z,x);
  if (length(y)<.001) { y=INV_VIEW_MATRIX[1].xyz; }
  y=normalize(y); z=normalize(cross(x,y));
 }
 vec3 rx=x*cos(a)+y*sin(a);
 vec3 ry=y*cos(a)-x*sin(a);
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(rx*size,0.),vec4(ry*size/aspect,0.),vec4(z*size,0.),MODEL_MATRIX[3]);
}
void fragment() {
 vec2 sample_uv=UV;
 // Magic recovery is local to the physical tip. The sword branch is unchanged.
 if(element==1 && dissolve>0.){
  float squeeze=1.-dissolve*.62;
  sample_uv=vec2(.94+(UV.x-.94)/squeeze,.5+(UV.y-.5)/(1.-dissolve*.35));
 }else if(element==3 && dissolve>0.){
  float squeeze=1.-dissolve*.8;
  sample_uv=vec2(.94+(UV.x-.94)/squeeze,.5+(UV.y-.5)/sqrt(squeeze));
 }
 if(any(lessThan(sample_uv,vec2(0.))) || any(greaterThan(sample_uv,vec2(1.)))){discard;}
 vec4 ink=texture(pixels,sample_uv);
 if (ink.a<.5 || opacity<.02) { discard; }
 // Steel converts to light from hilt to tip, along the same flow as the trail.
 vec2 cell=floor(UV*pixel_density/2.);
 float grain=fract(sin(dot(cell,vec2(12.9898,78.233)))*43758.5453);
 float threshold=clamp((UV.x-.06)/.88+(grain-.5)*.09,.001,.999);
 float front=smoothstep(.06,1.,dissolve);
 if(element==1){threshold=clamp((sample_uv.x-.18)/.76+(grain-.5)*.23,.001,.999);}
 if(element==2){threshold=clamp(1.-(UV.x-.16)/.78+(grain-.5)*.25,.001,.999);}
 if(element==3){threshold=clamp(.25+grain*.5+abs(sample_uv.y-.5)*2.,.001,.999);}
 if (dissolve>0. && threshold<front) { discard; }
 float edge=dissolve>0. ? (1.-step(.055,threshold-front))*.65 : 0.;
 ALBEDO=(max(edge,contact*step(.86,UV.x))>.3 ? hot_color.rgb : ink.rgb)*brightness;
 ALPHA=ink.a*opacity;
}
