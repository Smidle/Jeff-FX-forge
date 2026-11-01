shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
#include "res://addons/fx_forge/legacy/assets/missile_view.gdshaderinc"
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
// 镜头补偿（fx_missile.gd 每帧写入，世界坐标；拖尾节点是 top_level 且变换为单位矩阵）
uniform vec3 tip = vec3(0.);
uniform vec3 tail = vec3(0.);
uniform vec3 launch_tail = vec3(0.);
uniform vec3 head_direction = vec3(1.,0.,0.);
uniform bool view_compensation = false;
// 拖尾末端离发射点已经飞过的路程（米）。新拖尾（6～8）按世界路程取像素格，拖尾变长时像素不滑动
uniform float path_offset = 0.;
float hash(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}
float bayer2(vec2 p){return mod(2.*p.x+3.*p.y,4.);}
// 4×4 有序抖动阈值（0～1），用像素点阵表现半透明
float bayer4(vec2 c){vec2 p=mod(c,4.);return (4.*bayer2(mod(p,2.))+bayer2(floor(p/2.))+.5)/16.;}
// 拖尾条带宽度（顶点和片元共用）。新拖尾：焰旋的螺旋在火舌外侧，流光两侧有闪点，冰雾比霜线宽；
// 宽度取整到奇数个像素，横向像素和纵向一样是正方形。
float trail_extent(){
 float extent=width*max(1.,head_width)+turbulence*2.;
 if(trail_style<6){return extent;}
 extent*=trail_style==6 ? 2.2 : (trail_style==7 ? 1.4 : 2.2);
 return max(3.,floor(extent*density*.5)*2.+1.)/density;
}
void vertex() {
 vec3 tangent = normalize(COLOR.rgb * 2.0 - 1.0);
 if (view_compensation) {
  // 飞行接近视线时，按与弹头相同的倍数放大拖尾在屏幕上的长度（以弹尖为中心，深度保持真实），
  // 但拖尾末端不会越过发射点：刚发射时拖尾仍连回手上，飞出一段后才拉开。
  vec3 to_camera = missile_to_camera(tip, INV_VIEW_MATRIX, PROJECTION_MATRIX, CAMERA_POSITION_WORLD);
  float k = missile_view_stretch(head_direction, to_camera);
  vec3 tail_rel = tail - tip;
  vec3 launch_rel = launch_tail - tip;
  float tail_across = length(tail_rel - to_camera * dot(tail_rel, to_camera));
  float launch_across = length(launch_rel - to_camera * dot(launch_rel, to_camera));
  if (tail_across > 1e-4) { k = min(k, max(1., launch_across / tail_across)); }
  vec3 rel = VERTEX - tip;
  float rel_depth = dot(rel, to_camera);
  VERTEX = tip + (rel - to_camera * rel_depth) * k + to_camera * rel_depth;
  float tangent_depth = dot(tangent, to_camera);
  tangent = normalize((tangent - to_camera * tangent_depth) * k + to_camera * tangent_depth);
 }
 vec3 side = cross(INV_VIEW_MATRIX[2].xyz, tangent);
 if (length(side) < 0.001) { side = cross(vec3(0.,1.,0.),tangent); }
 if (length(side) < 0.001) { side = vec3(1.,0.,0.); }
 VERTEX += normalize(side) * (UV.y-.5) * trail_extent();
}
// 新拖尾（6 焰旋、7 流光、8 冰雾）。cell 是世界坐标固定的像素格；返回颜色，a<0 表示不画。
vec4 styled(float u, float under_blade, float across, float px, float erosion, vec2 cell) {
 float t=effect_time;
 float base=width*.5*max(1.,head_width);
 float shrink=pow(1.-under_blade,.65)*erosion*(1.-release*.65);
 float shape=abs(across);
 if(trail_style==6){
  // 火舌：只在弹头后方一小段，贴着弹头最粗；宽度随时间起伏
  float plume=base*1.15*pow(u,3.)*(.85+.15*sin(u*23.-t*13.)*sin(u*7.+t*5.));
  plume=mix(plume,neck_width*.5,smoothstep(.93,1.,u))*shrink;
  vec4 color=vec4(0.,0.,0.,-1.);
  // 只在火球附近保留 1 像素的芯，后面由两股螺旋连起来
  if(shape<max(plume,u>.8 ? px*.51*erosion*(1.-under_blade) : 0.)){
   float v=1.-shape/max(plume,.0001);
   color=vec4(v>.55 && u>.6 ? hot_color.rgb : (v>.25 ? light_color.rgb : mid_color.rgb),1.);
   // 最外一圈深红，压在暖色地面上也看得清
   if(shape>plume-px && plume>px*1.5){color.rgb=dark_color.rgb;}
  }
  // 两股绕飞行轴旋转的火焰（一股橙黄、一股赤红），从火球里绕出、往后越转越开。
  // 转到前面的部分亮、压在火舌上；转到后面的部分暗、被火舌挡住。相位随时间推进，看起来在旋转。
  // 尾部用点阵逐渐变稀。
  if(under_blade<=0. && u<.97 && release<.85){
   float turns=max(1.2,trail_length*1.25);
   float amp=base*mix(1.9,.9,u)*(1.-release*.6);
   // 一个像素对应的 u：按这一列左右两边的偏移填满中间，陡的地方也连成线
   float du=1./(density*max(.0001,trail_length*body_start));
   for(int k=0;k<2;k++){
    // 火焰被气流撕扯：两股的半径和相位都随位置、时间起伏，不是规整的螺旋线
    float phase=u*turns*6.2832+t*orbit_speed*6.+float(k)*3.14159+.55*sin(u*5.3+t*2.1+float(k)*2.3);
    float depth=cos(phase);
    bool front=depth>0.;
    if(u<.35 && bayer4(cell+vec2(float(k)*2.,0.))>u/.35){continue;}
    float thick=px*(front && u>.3 ? 1.05 : .55);
    float half_step=du*.5*turns*6.2832;
    float ragged=amp*(.72+.38*sin(u*9.-t*4.+float(k)*1.7));
    float o0=sin(phase-half_step)*ragged;
    float o1=sin(phase+half_step)*ragged;
    if(across>min(o0,o1)-thick && across<max(o0,o1)+thick){
     vec3 c=k==0 ? (front ? (depth>.7 ? hot_color.rgb : light_color.rgb) : mid_color.rgb)
      : (front ? (depth>.7 ? light_color.rgb : mid_color.rgb) : dark_color.rgb);
     if(front || color.a<0.){color=vec4(c,1.);}
    }
   }
  }
  return color;
 }
 if(trail_style==7){
  // 流光：1 像素白热核心、两侧浅色；亮段从弹头往尾部流；尾端断成光点，越靠尾越稀
  float r=width*.5*mix(tip_width,head_width,pow(u,taper));
  r=mix(r,neck_width*.5,smoothstep(.62,1.,u))*shrink;
  r=max(r,px*.51*erosion*(1.-under_blade));
  if(u<.4 && hash(vec2(cell.x,3.))>u/.4+.15){return vec4(-1.);}
  bool bright=fract(u*2.6+t*2.2)<.22 && u>.12;
  if(shape<r){
   float v=1.-shape/r;
   bool core=shape<px*.5;
   vec3 c=core ? hot_color.rgb : (v>.35 ? light_color.rgb : mid_color.rgb);
   if(bright){c=core||v>.35 ? hot_color.rgb : light_color.rgb;}
   if(u<.25){c=core ? light_color.rgb : mid_color.rgb;}
   return vec4(c,1.);
  }
  // 两侧偶尔闪出的光点
  if(shape<r+px*1.6 && u>.2 && u<.92 && under_blade<=0. && hash(cell+vec2(floor(t*14.)*7.,0.))>.975){return vec4(hot_color.rgb,1.);}
  return vec4(-1.);
 }
 // 冰雾：中间一条断续霜线（靠弹头处连续），外面是点阵的淡寒气，中间浓边缘淡、越靠弹头越浓，零星冰点闪烁
 bool thread=shape<px*.5 && (u>.7 || hash(vec2(floor(cell.x/3.),1.))<.35+.6*u) && shrink>.05;
 float halfw=trail_extent()*.5*mix(.55,1.,u);
 float d=clamp(1.-shape/halfw,0.,1.);
 // 随机点阵（不用有序抖动，避免排成竖条），按世界像素格固定，箭飞走后寒气留在原地
 bool haze=under_blade<=0. && hash(cell*1.37+vec2(4.1,2.3))<d*(.12+.42*u)*shrink;
 if(thread){return vec4(u>.75 ? hot_color.rgb : light_color.rgb,1.);}
 if(haze){return vec4(hash(cell+vec2(floor(t*10.)*13.,5.))>.92 ? hot_color.rgb : (d>.45 ? light_color.rgb : mid_color.rgb),1.);}
 return vec4(-1.);
}
void fragment() {
 float cells=max(1.,trail_length*density);
 float along=min(1.,(floor(UV.x*cells)+.5)/cells);
 float extent=trail_extent();
 float across_cells=max(3.,ceil(extent*density));
 // Use an odd number of rows, so even a very fine trail has a centre pixel.
 across_cells=floor(across_cells*.5)*2.+1.;
 if (trail_style>=6) { across_cells=floor(extent*density+.5); }
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
 if (trail_style>=6) {
  // 世界坐标固定的像素格：沿路程每 1/density 米一格，横向与纵向等大
  float world=path_offset+UV.x*trail_length;
  float cx=floor(world*density);
  float along_w=clamp(((cx+.5)/density-path_offset)/max(.0001,trail_length),0.,1.);
  float px=extent/across_cells;
  vec4 c=styled(clamp(along_w/max(.0001,body_start),0.,1.),clamp((along_w-body_start)/max(.0001,1.-body_start),0.,1.),across,px,erosion,vec2(cx,floor(UV.y*across_cells)));
  if (c.a<0.) { discard; }
  ALBEDO=c.rgb*brightness;
  ALPHA=opacity*(1.-smoothstep(.88,1.,release));
 } else {
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
}
