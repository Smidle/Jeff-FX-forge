shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 dark_color : source_color;
uniform vec4 mid_color : source_color;
uniform vec4 light_color : source_color;
uniform vec4 hot_color : source_color;
uniform vec3 direction=vec3(1.,0.,0.);
uniform int element=1;
uniform bool impact_mode=false;
uniform float age=-1.;
uniform float duration=.4;
uniform float dissolve_duration=.2;
uniform float body_length=.7;
uniform float size=1.;
uniform float brightness=1.;
uniform float opacity=1.;
varying float phase;
varying float alive;
varying float noise;
void vertex(){
 float u=INSTANCE_CUSTOM.x;noise=INSTANCE_CUSTOM.y;
 float birth=impact_mode ? duration*u*.07 : dissolve_duration*(element==2 ? 1.-u : u)*.6;
 phase=clamp((age-birth)/max(.001,duration-birth),0.,1.);
 alive=step(birth,age)*(1.-step(duration,age));
 vec3 forward=normalize(direction);vec3 view=INV_VIEW_MATRIX[2].xyz;
 vec3 side=cross(view,forward);if(length(side)<.001){side=INV_VIEW_MATRIX[1].xyz;}side=normalize(side);
 vec3 origin=MODEL_MATRIX[3].xyz;
 float side_sign=INSTANCE_CUSTOM.z>.5 ? 1. : -1.;
 float theta=u*6.283185+noise*.7;
 if(!impact_mode){origin-=forward*body_length*(1.-u)*size;}
 vec3 travel;
 if(element==1){
  travel=(forward*cos(theta)+side*sin(theta))*(.12+noise*.28)*size*sqrt(phase);
  travel+=vec3(0.,1.,0.)*.20*size*phase*phase;
 }else if(element==2){
  travel=forward*(.15+noise*.38)*size*phase+side*side_sign*(.08+u*.23)*size*phase;
  travel-=vec3(0.,1.,0.)*.23*size*phase*phase;
 }else{
  float radius=(.12+noise*.18)*sin(phase*3.14159);
  travel=(forward*cos(theta+phase*2.)+side*sin(theta+phase*2.))*radius*size;
 }
 origin+=travel;
 vec3 x=INV_VIEW_MATRIX[0].xyz;vec3 y=INV_VIEW_MATRIX[1].xyz;
 if(element==2){x=normalize(forward+side*side_sign*(.25+noise));y=cross(view,x);if(length(y)<.001){y=INV_VIEW_MATRIX[1].xyz;}y=normalize(y);}
 float scale=size*(impact_mode ? .07+.075*noise : .025+.04*noise)*(1.-.75*phase);
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(x*scale,0.),vec4(y*scale,0.),vec4(view,0.),vec4(origin,1.));
}
void fragment(){
 if(alive<.5 || opacity<.01){discard;}
 vec2 p=(floor(UV*9.)+.5)/9.-.5;
 float shade=1.;
 if(element==1){
  if(length(p*vec2(1.5,1.))>.40 || p.y<-.35+abs(p.x)*.6){discard;}
  shade=length(p)<.16 ? (phase<.3 ? 3. : 2.) : (phase<.4 ? 1. : 0.);
 }else if(element==2){
  if(abs(p.x)*1.05+abs(p.y)*2.4>.5){discard;}
  shade=p.y<-.02 ? 2. : (p.y<.06 ? 3. : 1.);
 }else{
  float curl=.13*sin(p.x*8.+phase*4.+noise*3.);
  if(abs(p.y-curl)>.12*(1.-abs(p.x)*1.5) || abs(p.x)>.44){discard;}
  shade=p.y<curl ? 1. : (phase<.3 ? 2. : 0.);
 }
 ALBEDO=(shade>2.5 ? hot_color.rgb : (shade>1.5 ? light_color.rgb : (shade>.5 ? mid_color.rgb : dark_color.rgb)))*brightness;
 ALPHA=opacity*(1.-smoothstep(.7,1.,phase));
}
