shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 dark_color : source_color;
uniform vec4 mid_color : source_color;
uniform vec4 light_color : source_color;
uniform vec4 hot_color : source_color;
uniform vec3 direction=vec3(1.,0.,0.);
uniform float size=1.;
uniform float density=64.;
uniform float progress=-1.;
uniform float ornament=0.;
uniform float brightness=1.;
uniform float opacity=1.;
uniform int style=3;
uniform int facing=0;
varying vec2 incoming;
void vertex(){
 vec3 x=INV_VIEW_MATRIX[0].xyz; vec3 y=INV_VIEW_MATRIX[1].xyz; vec3 z=INV_VIEW_MATRIX[2].xyz;
 if(facing==1){x=vec3(1.,0.,0.);y=vec3(0.,0.,-1.);z=vec3(0.,1.,0.);}
 if(facing==2){z=normalize(direction);x=cross(vec3(0.,1.,0.),z);if(length(x)<.001){x=vec3(1.,0.,0.);}x=normalize(x);y=normalize(cross(z,x));}
 incoming=vec2(dot(direction,x),-dot(direction,y));
 if(length(incoming)<.01){incoming=vec2(1.,0.);}incoming=normalize(incoming);
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(x*size,0.),vec4(y*size,0.),vec4(z*size,0.),MODEL_MATRIX[3]);
}
float segment(vec2 p,vec2 a,vec2 b){vec2 v=b-a;return length(p-a-v*clamp(dot(p-a,v)/max(.00001,dot(v,v)),0.,1.));}
void fragment(){
 if(progress<0. || progress>=1. || opacity<.01){discard;}
 float p=progress;float px=1./density;
 vec2 point=(floor(UV*density)+.5)/density-.5;
 vec2 q=vec2(dot(point,incoming),dot(point,vec2(-incoming.y,incoming.x)));
 float r=length(q);float a=atan(q.y,q.x);float shade=-1.;
 if(style==3){
  // Six separated rolling petals; holes grow as hot folds cool into embers.
  float growth=sin(min(p*3.5,1.)*1.5708);
  float radius=(.045+.29*growth)*pow(1.-p,.45);
  float lobe=.84+.14*sin(a*6.+p*5.)+.06*sin(a*11.-p*8.);
  float outer=radius*lobe;
  float inner=radius*(.18+smoothstep(.12,.78,p)*.65);
  float tongues=sin(a*6.+p*5.);
  if(r<outer && r>inner && (tongues>-.65+smoothstep(.4,.95,p)*1.5 || p<.15)){
   float fold=(r-inner)/max(px,outer-inner);
   shade=fold<.3 ? 2. : (fold<.7 ? 1. : 0.);
   if(p<.24 && fold<.14){shade=3.;}
   if(sin(a*9.-r*26.+p*11.)>.55 && fold>.3){shade=max(0.,shade-1.);}
  }
  if(p<.17 && r<.105*(1.-p/.17)){shade=r<.045 ? 3. : 2.;}
  float ring=.12+sqrt(p)*.32;
  if(ornament>.01 && p<.55 && abs(r-ring)<px*.7 && sin(a*6.-p*5.)>.25){shade=max(shade,1.);}
 } else if(style==4){
  // Contact flare and a hexagonal frost seal; the directional shards are instanced.
  float flash=1.-smoothstep(.03,.25,p);
  if(abs(q.y)<px*.6 && abs(q.x)<.17*flash){shade=3.;}
  if(abs(q.x)<px*.55 && abs(q.y)<.10*flash){shade=2.;}
  float radius=(.07+.28*sin(min(p*3.,1.)*1.5708));
  for(int edge=0;edge<6;edge++){
   float theta=float(edge)*1.04719755+.5236;
   vec2 v=vec2(cos(theta),sin(theta))*radius;
   vec2 w=vec2(cos(theta+1.04719755),sin(theta+1.04719755))*radius;
   if(ornament>.01 && p<.75 && segment(q,v,w)<px*.6 && sin((q.x+q.y)*59.+float(edge)*2.)>mix(-1.,.85,p)) {shade=max(shade,p<.35 ? 2. : 1.);}
   if(ornament>.01 && p<.45 && segment(q,v*.73,v*1.15)<px*.55){shade=max(shade,1.);}
  }
 } else {
  // A narrow violet rupture: no opaque black disc obscuring the target.
  float open=sin(min(p*3.2,1.)*1.5708)*pow(1.-p,1.2);
  float width=.055*open*(1.-abs(q.y)/.34);
  float zig=sin(floor(q.y*density/3.)*2.1)*px;
  if(abs(q.y)<.32*open && abs(q.x-zig)<max(0.,width)) {shade=abs(q.x-zig)<width*.38 ? 0. : 2.;}
  if(p<.12 && r<.045*(1.-p/.12)){shade=3.;}
  float radius=(.10+.27*sin(min(p*3.8,1.)*1.5708))*pow(1.-p,.65);
  float ring=radius*(1.+.08*sin(a*3.+p*5.));
  if(ornament>.01 && abs(r-ring)<px*.65 && sin(a*5.+p*6.)>.1+p*.7){shade=max(shade,p<.28 ? 2. : 1.);}
  for(int mark=0;mark<3;mark++){
   float theta=float(mark)*2.0944+p*1.2;vec2 v=vec2(cos(theta),sin(theta));
   if(ornament>.01 && p<.6 && segment(q,v*radius*.72,v*radius*1.2)<px*.6){shade=max(shade,1.);}
  }
 }
 if(shade<0.){discard;}
 ALBEDO=(shade>2.5 ? hot_color.rgb : (shade>1.5 ? light_color.rgb : (shade>.5 ? mid_color.rgb : dark_color.rgb)))*brightness;
 ALPHA=opacity*(1.-smoothstep(.82,1.,p));
}
