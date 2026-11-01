shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
#include "res://addons/fx_forge/legacy/assets/missile_view.gdshaderinc"
// 拖尾粒子：出生后留在世界里，运动、闪烁、消散都在这里按年龄计算，fx_missile.gd 只在出生时写一次。
// 实例变换：原点 = 出生点（弹头中心），basis.x = 出生时的飞行方向；自定义数据：x = 出生时间，yzw = 随机数。
// 样子跟随弹头造型：御剑是十字剑光，火球是冷却成烟的火团和往上飘的火星，寒冰是冰晶、雪花和闪点，
// 暗影是边缘透着紫光的半透明暗烟和紫色余烬。火团冷却后、暗烟都是真正半透明的（pixelfx 的烟），不用点阵。
uniform vec4 dark_color : source_color;
uniform vec4 mid_color : source_color;
uniform vec4 light_color : source_color;
uniform vec4 hot_color : source_color;
uniform int element = 0;
uniform float life = .6;
// 一个像素的世界尺寸，与拖尾相同
uniform float pixel = .04;
uniform float size = 1.;
uniform float density = 64.;
uniform float effect_time = 0.;
uniform float brightness = 1.;
uniform float opacity = 1.;
// 镜头补偿（与拖尾同一组参数）
uniform vec3 tip = vec3(0.);
uniform vec3 tail = vec3(0.);
uniform vec3 launch_tail = vec3(0.);
uniform vec3 head_direction = vec3(1.,0.,0.);
uniform bool view_compensation = false;
varying flat float age;
varying flat vec3 noise;
varying flat float cells;
varying flat float kind;
float hash(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}
float bayer2(vec2 p){return mod(2.*p.x+3.*p.y,4.);}
float bayer4(vec2 c){vec2 p=mod(c,4.);return (4.*bayer2(mod(p,2.))+bayer2(floor(p/2.))+.5)/16.;}
void vertex() {
 age=(effect_time-INSTANCE_CUSTOM.x)/max(.05,life);
 noise=INSTANCE_CUSTOM.yzw;
 vec3 forward=normalize(MODEL_MATRIX[0].xyz);
 vec3 origin=MODEL_MATRIX[3].xyz;
 vec3 view=INV_VIEW_MATRIX[2].xyz;
 if (view_compensation) {
  // 出生点按拖尾相同的倍数放大屏幕长度，朝远处打时粒子仍贴着拖尾；粒子自己的漂移不放大
  vec3 to_camera=missile_to_camera(tip,INV_VIEW_MATRIX,PROJECTION_MATRIX,CAMERA_POSITION_WORLD);
  float k=missile_view_stretch(head_direction,to_camera);
  vec3 tail_rel=tail-tip;
  vec3 launch_rel=launch_tail-tip;
  float tail_across=length(tail_rel-to_camera*dot(tail_rel,to_camera));
  float launch_across=length(launch_rel-to_camera*dot(launch_rel,to_camera));
  if (tail_across>1e-4) { k=min(k,max(1.,launch_across/tail_across)); }
  vec3 rel=origin-tip;
  float depth=dot(rel,to_camera);
  origin=tip+(rel-to_camera*depth)*k+to_camera*depth;
 }
 vec3 side=cross(view,forward);
 side=length(side)<.001 ? INV_VIEW_MATRIX[0].xyz : normalize(side);
 vec3 up=vec3(0.,1.,0.);
 float s=max(age,0.)*life;
 float n1=noise.x*2.-1.;
 float n2=noise.y*2.-1.;
 float spread=fract(noise.z*7.31);
 vec3 offset=vec3(0.);
 kind=0.;
 cells=5.;
 if (element==1) {
  // 火：约七成是火团，从火球后面掉出来、往后上方飘着胀大，由白热冷却成暗红再变成烟；三成是往上飘的火星
  kind=noise.z<.3 ? 1. : 0.;
  if (kind<.5) {
   float drift=(1.-exp(-s*3.))/3.;
   offset=-forward*size*(.05+.18*spread)+(-forward*.5+side*n1*.35+up*(.25+.3*noise.y))*drift+up*.15*s*s;
   cells=13.;
  } else {
   offset=-forward*size*(.08+.22*spread)+(-forward*.35+side*n1*.6+up*(.2+.4*noise.y))*s+up*.8*s*s;
   cells=3.;
  }
 } else if (element==2) {
  // 冰：沿箭身散出，很快停住，再慢慢往下飘
  kind=noise.z<.22 ? 1. : (noise.z<.55 ? 2. : 0.);
  float drift=(1.-exp(-s*4.))/4.;
  offset=-forward*size*(.1+.6*spread)+(side*n1*.9+up*n2*.6-forward*.15)*drift-up*.22*s*s;
  cells=kind>.5 && kind<1.5 ? 7. : 5.;
 } else if (element==3) {
  // 暗影：大多是往后上方飘、慢慢胀开的暗烟（上缘透着紫光），左右轻轻摆；约四分之一是紫色余烬
  kind=noise.z<.25 ? 1. : 0.;
  float drift=(1.-exp(-s*2.5))/2.5;
  offset=-forward*size*(.1+.3*spread)+(-forward*.3+side*n1*.3+up*(.2+.15*noise.y))*drift+side*sin(s*6.+n2*6.)*.05+up*.1*s*s;
  cells=kind<.5 ? 11. : 3.;
 } else {
  // 剑光：沿剑身出现，基本不动，一闪就灭
  offset=-forward*size*(.1+.75*spread)+side*n1*pixel*3.+up*n2*pixel*3.;
  cells=7.;
 }
 origin+=offset;
 // 还没出生或已经消失的粒子缩成一点，不产生像素
 float scale=cells*pixel*step(0.,age)*step(age,1.);
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(INV_VIEW_MATRIX[0].xyz*scale,0.),vec4(INV_VIEW_MATRIX[1].xyz*scale,0.),vec4(view*scale,0.),vec4(origin,1.));
}
void fragment() {
 if (age<0. || age>1. || opacity<.01) { discard; }
 vec2 c=floor(UV*cells);
 vec2 p=c-floor(cells*.5);
 float a=age;
 float shade=0.;
 vec3 smoke=vec3(-1.);
 // 半透明的烟（火团冷却后、暗烟）：直接给出颜色和透明度，跳过后面的点阵消散
 vec4 haze=vec4(-1.);
 if (element==1) {
  if (kind>.5) {
   // 火星：先 2×2 后 1 像素，白热 → 亮 → 中 → 暗红，后半段偶尔闪灭
   bool on=a<.35 ? (p.x>-1.5 && p.x<.5 && p.y>-1.5 && p.y<.5) : (abs(p.x)<.5 && abs(p.y)<.5);
   if (!on || (a>.5 && hash(vec2(noise.x*97.,floor(effect_time*20.)))<.2)) { discard; }
   shade=a<.22 ? 3. : (a<.5 ? 2. : (a<.8 ? 1. : 0.));
  } else {
   // 火团：边缘参差的圆，边飘边胀大；中心比边缘热，整体由白热 → 亮 → 中 → 暗红冷却，之后变成烟，
   // 烟是真正半透明的灰，上缘留一点火光，最后淡出
   float r=mix(1.4+noise.y,5.2+noise.x,sqrt(a));
   float d=length(p)+hash(c+floor(noise.xy*9.))*.9;
   if (d>r) { discard; }
   float heat=1.15-a*1.9-d/max(r,.1)*.35;
   if (heat>0.) {
    shade=heat>.8 ? 3. : (heat>.55 ? 2. : (heat>.3 ? 1. : 0.));
    vec3 fire=shade>2.5 ? hot_color.rgb : (shade>1.5 ? light_color.rgb : (shade>.5 ? mid_color.rgb : dark_color.rgb));
    haze=vec4(fire,1.);
   } else {
    vec3 grey=p.y<-r*.3 && a<.6 ? mix(dark_color.rgb,vec3(.46,.42,.4),.6) : vec3(.27,.25,.25);
    haze=vec4(grey,.7*(1.-smoothstep(.45,1.,a)));
   }
  }
 } else if (element==2) {
  bool twinkle=hash(vec2(noise.y*53.,floor(effect_time*12.)))>.7;
  if (kind>.5 && kind<1.5) {
   // 雪花：米字形，随年龄缩小
   float r=floor(mix(3.,1.,a)+.5);
   bool arm=abs(p.x)<.5 || abs(p.y)<.5 || abs(abs(p.x)-abs(p.y))<.5;
   if (!arm || max(abs(p.x),abs(p.y))>r) { discard; }
   shade=(abs(p.x)<.5 && abs(p.y)<.5) || twinkle ? 3. : 2.;
  } else if (kind>1.5) {
   // 闪点：1 像素 → 十字 → 1 像素
   float r=floor(sin(a*3.14159)*2.+.5);
   if (!((abs(p.x)<.5 && abs(p.y)<=r) || (abs(p.y)<.5 && abs(p.x)<=r))) { discard; }
   shade=abs(p.x)+abs(p.y)<.5 ? 3. : 2.;
  } else {
   // 冰晶：竖长的菱形，随年龄缩小，上亮下暗，中心闪烁
   float r=mix(2.,.6,a);
   if (abs(p.x)*1.4+abs(p.y)>r+.01) { discard; }
   shade=abs(p.x)+abs(p.y)<.5 ? (twinkle ? 3. : 2.) : (p.y<0. ? 2. : 1.);
  }
 } else if (element==3) {
  if (kind>.5) {
   // 紫色余烬：1 像素，偶尔闪灭
   if (abs(p.x)>.5 || abs(p.y)>.5 || hash(vec2(noise.x*61.,floor(effect_time*16.)))<.25) { discard; }
   shade=a<.4 ? 3. : 2.;
  } else {
   // 暗烟：边缘参差、慢慢胀开的半透明暗色烟团，上缘透着紫光
   float r=mix(1.4+noise.y,4.6+noise.x,sqrt(a));
   float d=length(p)+hash(c+floor(noise.xy*9.))*.9;
   if (d>r) { discard; }
   vec3 tone=p.y<-r*.35 ? (a<.35 ? light_color.rgb : mid_color.rgb) : dark_color.rgb;
   haze=vec4(tone,.75*(1.-smoothstep(.35,1.,a)));
  }
 } else {
  // 剑光：十字星，1 → 3 → 1 像素
  float r=floor(sin(a*3.14159)*3.+.5);
  if (!((abs(p.x)<.5 && abs(p.y)<=r) || (abs(p.y)<.5 && abs(p.x)<=r))) { discard; }
  float d=abs(p.x)+abs(p.y);
  shade=d<.5 ? 3. : (d<1.5 ? 2. : 1.);
 }
 if (haze.r>=0.) {
  ALBEDO=haze.rgb*brightness;
  ALPHA=opacity*haze.a;
 } else {
 // 最后四分之一用点阵逐渐变稀，不用整体半透明
 if (a>.75 && bayer4(c+floor(noise.zx*5.))>(1.-a)*4.) { discard; }
 vec3 color=shade>2.5 ? hot_color.rgb : (shade>1.5 ? light_color.rgb : (shade>.5 ? mid_color.rgb : dark_color.rgb));
 ALBEDO=(smoke.r>=0. ? smoke : color)*brightness;
 ALPHA=opacity;
 }
}
