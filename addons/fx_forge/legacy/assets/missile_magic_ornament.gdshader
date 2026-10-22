shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 dark_color : source_color;
uniform vec4 mid_color : source_color;
uniform vec4 light_color : source_color;
uniform vec4 hot_color : source_color;
uniform vec3 direction=vec3(1.,0.,0.);
uniform int element=1;
uniform float size=1.;
uniform float aspect=1.;
uniform float density=64.;
uniform float effect_time=0.;
uniform float speed=1.;
uniform float strength=0.;
uniform float release=0.;
uniform float brightness=1.;
uniform float opacity=1.;
uniform bool reduced=false;
void vertex() {
 vec3 x=normalize(direction);
 vec3 z=INV_VIEW_MATRIX[2].xyz;
 vec3 y=cross(z,x);
 if(length(y)<.001){y=INV_VIEW_MATRIX[1].xyz;}
 y=normalize(y); z=normalize(cross(x,y));
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(x*size*1.45,0.),vec4(y*size*1.45/aspect,0.),vec4(z,0.),MODEL_MATRIX[3]);
}
float segment(vec2 p,vec2 a,vec2 b){vec2 v=b-a;return length(p-a-v*clamp(dot(p-a,v)/max(.00001,dot(v,v)),0.,1.));}
void fragment() {
 if(strength<=.001 || release>=1. || opacity<.01){discard;}
 vec2 q=((floor(UV*density*1.45)+.5)/(density*1.45)-.5)*1.45;
 // The quad shares the head centre; x=.44 is the physical contact point.
 float age=effect_time*speed;
 float shrink=1.-smoothstep(.0,1.,release);
 float px=1./density;
 float shade=-1.;
 for(int band=0;band<2;band++){
  if(reduced && band==1){continue;}
  float phase=age*(element==1 ? 6. : (element==2 ? 3.5 : 4.5))+float(band)*3.14159;
  float u=clamp((q.x+.52)/.92,0.,1.);
  float envelope=sin(u*3.14159);
  float radius=(element==2 ? .16 : .24)*(.65+.35*strength)*shrink;
  float wave=sin(u*7.+phase)*radius*envelope;
  float width=px*(element==1 ? 1.4 : .7)*(.4+.6*envelope);
  if(element==3){width=px*(.8+1.6*envelope);}
  float d=abs(q.y-wave);
  if(q.x>-.52 && q.x<.40 && d<max(px*.46,width)){
   float depth=cos(u*7.+phase);
   // Cross behind the core, so orbit bands read as wrapping a solid object.
   bool behind=depth<-.25 && q.x>-.08 && abs(q.y)<.13;
   if(!behind){shade=max(shade,depth>.25 ? 2. : (element==3 ? 0. : 1.));}
   if(!behind && element==1 && d<px*.45 && depth>.7){shade=3.;}
  }
  if(element==2){
   vec2 c=vec2(-.13+.14*cos(phase),.19*sin(phase));
   vec2 ice=q-c;
   if(abs(ice.x)/.048+abs(ice.y)/.026<shrink){shade=max(shade,ice.y<0. ? 3. : 1.);}
  }
 }
 // Broken, original geometric glyphs: tiny accents rather than a large disc.
 for(int glyph=0;glyph<3;glyph++){
  if(reduced && glyph>0){continue;}
  float a=float(glyph)*2.0944+age*.65;
  vec2 c=vec2(.05+cos(a)*.27,sin(a)*.29)*(.8+.2*strength)*shrink;
  vec2 p=q-c;
  float len=.026+.014*strength;
  float mark=min(segment(p,vec2(-len,0.),vec2(0.,-len)),segment(p,vec2(0.,-len),vec2(len,0.)));
  if(element!=2){mark=min(mark,segment(p,vec2(-len*.4,0.),vec2(len*.4,len)));}
  if(mark<px*.47 && sin(a*2.+age)>-.3 && strength>.18){shade=max(shade,1.);}
 }
 if(shade<0. || abs(q.y)>.55){discard;}
 ALBEDO=(shade>2.5 ? hot_color.rgb : (shade>1.5 ? light_color.rgb : (shade>.5 ? mid_color.rgb : dark_color.rgb)))*brightness;
 ALPHA=opacity*strength*(1.-smoothstep(.75,1.,release));
}
