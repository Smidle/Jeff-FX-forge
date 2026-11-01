shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
#include "res://addons/fx_forge/legacy/assets/missile_view.gdshaderinc"
// 弹头残影：采样弹头贴图（剑穗等动画同步），按亮度换成气色，越远越淡。
// 实例变换：原点 = 残影的弹尖（fx_missile.gd 已做屏幕长度补偿），basis.x = 当时的飞行方向；
// 自定义数据 x = 浓度（0～1）。
uniform sampler2D pixels : source_color, filter_nearest, repeat_disable;
uniform vec4 mid_color : source_color;
uniform vec4 light_color : source_color;
uniform vec4 hot_color : source_color;
uniform float size = 1.;
uniform float aspect = 1.;
uniform float brightness = 1.;
uniform float opacity = 1.;
varying flat float strength;
void vertex() {
 strength=INSTANCE_CUSTOM.x;
 vec3 direction=normalize(MODEL_MATRIX[0].xyz);
 vec3 tip=MODEL_MATRIX[3].xyz;
 // 与弹头相同的轴向补偿：弹尖落在残影位置，飞行接近视线时补足屏幕长度
 vec3 axis=missile_view_axis(direction,tip,INV_VIEW_MATRIX,PROJECTION_MATRIX,CAMERA_POSITION_WORLD);
 vec3 origin=tip-axis*size*TIP_ANCHOR;
 float length_scale=length(axis);
 vec3 x=axis/length_scale;
 vec3 z=INV_VIEW_MATRIX[2].xyz;
 vec3 y=cross(z,x);
 if (length(y)<.001) { y=INV_VIEW_MATRIX[1].xyz; }
 y=normalize(y); z=normalize(cross(x,y));
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(x*size*length_scale,0.),vec4(y*size/aspect,0.),vec4(z*size,0.),vec4(origin,1.));
}
void fragment() {
 vec4 ink=texture(pixels,UV);
 if (ink.a<.5 || opacity<.02 || strength<=0.) { discard; }
 // 剑身等亮部换成浅色气光，其余（描边、剑柄）换成中间色；整体按浓度半透明
 float lum=dot(ink.rgb,vec3(.3,.59,.11));
 ALBEDO=(lum>.8 ? hot_color.rgb : (lum>.45 ? light_color.rgb : mid_color.rgb))*brightness;
 ALPHA=opacity*strength;
}
