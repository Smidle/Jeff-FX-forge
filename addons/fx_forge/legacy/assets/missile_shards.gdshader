shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 light_color : source_color;
uniform vec4 hot_color : source_color;
uniform vec3 direction=vec3(1.,0.,0.);
uniform float size=1.;
uniform float age=0.;
uniform float dissolve_duration=.16;
uniform float tail_duration=.35;
uniform float brightness=1.;
uniform float opacity=1.;
uniform int element=0;
varying float phase;
varying float alive;
void vertex() {
 float u=INSTANCE_CUSTOM.x;
 float noise=INSTANCE_CUSTOM.y;
 float birth=dissolve_duration*mix(.14,.82,u);
 phase=clamp((age-birth)/max(.001,tail_duration-birth),0.,1.);
 alive=step(birth,age)*(1.-step(tail_duration,age));
 vec3 forward=normalize(direction);
 vec3 side=cross(INV_VIEW_MATRIX[2].xyz,forward);
 if (length(side)<.001) { side=INV_VIEW_MATRIX[1].xyz; }
 side=normalize(side)*(INSTANCE_CUSTOM.z>.5 ? 1. : -1.);
 vec3 origin=MODEL_MATRIX[3].xyz-forward*(.84*(1.-u))*size;
 origin+=forward*(.04+.16*noise)*size*phase;
 origin+=side*(.06+.16*noise)*size*phase;
 origin+=vec3(0.,1.,0.)*.045*size*phase*phase;
 if (element==1) { origin+=vec3(0.,1.,0.)*.14*size*phase*phase; }
 if (element==2) { origin-=vec3(0.,1.,0.)*.09*size*phase*phase; }
 if (element==3) { origin=mix(origin,MODEL_MATRIX[3].xyz,phase*.65); }
 vec3 x=INV_VIEW_MATRIX[0].xyz;
 vec3 y=INV_VIEW_MATRIX[1].xyz;
 float scale=size*(.026+.020*noise)*(1.-.65*phase);
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(x*scale,0.),vec4(y*scale,0.),vec4(INV_VIEW_MATRIX[2].xyz*scale,0.),vec4(origin,1.));
}
void fragment() {
 vec2 cell=floor(UV*3.);
 if (alive<.5 || abs(cell.x-1.)+abs(cell.y-1.)>1.) { discard; }
 ALBEDO=mix(hot_color.rgb,light_color.rgb,phase)*brightness;
 ALPHA=opacity*(1.-smoothstep(.45,1.,phase));
}
