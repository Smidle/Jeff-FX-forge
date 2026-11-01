// 飞弹弹头的镜头补偿（弹头、魔法环带、消散碎光、元素碎片共用）。
//
// 弹头按真实三维长度沿飞行方向摆放。飞行方向接近视线时（2.5D 低角度镜头下从屏幕下方往上打，
// 或朝镜头飞来），它在屏幕上的长度只剩 sin(夹角)，看起来被压成一小团或一条细线。
// 这里保留弹头在深度方向的真实走向（遮挡和前后关系不变），只把屏幕上的长度补到
// 不少于 MIN_SCREEN_LENGTH；侧向飞行时屏幕长度本来就够，结果与原来完全相同。
// 调用方再用 TIP_ANCHOR 把弹尖放回真实的三维位置，保证飞弹仍然准确落在命中点上。

// fx_missile.gd 的 VIEW_MIN_SCREEN_LENGTH 必须与此一致（拖尾碎光在 CPU 上做同样的补偿）
const float MIN_SCREEN_LENGTH = 0.85;
// 与 fx_missile.gd 中弹头节点相对接触点的后移量（head_size * .44）一致
const float TIP_ANCHOR = 0.44;
// 拖尾放大倍数上限，避免正对镜头时数值失控
const float MAX_STRETCH = 8.0;

// 正交镜头用镜头朝向，透视镜头用物体到镜头的视线
vec3 missile_to_camera(vec3 origin, mat4 inv_view, mat4 projection, vec3 camera_world) {
	return projection[3][3] == 1.0 ? inv_view[2].xyz : normalize(camera_world - origin);
}

// 拖尾等沿路径分布的部分：屏幕平面内相对弹尖的放大倍数（≥ 1），与弹头的补偿完全一致，
// 所以拖尾和弹头的衔接点仍然对齐。
float missile_view_stretch(vec3 direction, vec3 to_camera) {
	vec3 d = normalize(direction);
	float s = length(d - to_camera * dot(d, to_camera));
	return clamp(max(s, MIN_SCREEN_LENGTH) / max(s, 1e-4), 1.0, MAX_STRETCH);
}

// 返回补偿后的弹头轴向（世界坐标，未归一化：长度 ≥ 1）。
vec3 missile_view_axis(vec3 direction, vec3 origin, mat4 inv_view, mat4 projection, vec3 camera_world) {
	vec3 d = normalize(direction);
	vec3 to_camera = missile_to_camera(origin, inv_view, projection, camera_world);
	float depth = dot(d, to_camera);
	vec3 across = d - to_camera * depth;
	float s = length(across);
	// 正对镜头时没有屏幕方向可用：远离镜头的飞弹在画面上往上走，朝向镜头的往下走
	vec3 fallback = inv_view[1].xyz * (depth < 0.0 ? 1.0 : -1.0);
	vec3 screen_dir = fallback;
	if (s > 1e-4) {
		screen_dir = across / s;
		// 两个方向在同一侧时再混合，避免接近正对时翻转
		if (dot(screen_dir, fallback) < 0.0) { fallback = -fallback; }
		screen_dir = normalize(mix(fallback, screen_dir, smoothstep(0.0, 0.05, s)));
	}
	return screen_dir * max(s, MIN_SCREEN_LENGTH) + to_camera * depth;
}
