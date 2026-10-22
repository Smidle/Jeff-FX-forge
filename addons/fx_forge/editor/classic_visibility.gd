@tool
extends RefCounted
## Measured with the built-in recipes. Resource fields remain intact.
## See docs/parameter-audit.md and tools/build_classic_visibility.py.
const HIDDEN := {
	"smoke/0": [
		"animation_loop"
	],
	"smoke/1": [
		"animation_loop"
	],
	"rain/1": [
		"sort_priority"
	],
	"portal/2": [
		"animation_loop"
	],
	"procedural_flame/-1": [
		"looping"
	],
	"procedural_flame/0": [
		"sort_priority",
		"duration"
	],
	"wuxia_parry/-1": [
		"looping"
	],
	"wuxia_parry/0": [
		"animation_loop",
		"sort_priority"
	],
	"wuxia_parry/1": [
		"sort_priority",
		"animation_loop"
	],
	"wuxia_dust/-1": [
		"looping"
	],
	"wuxia_dust/0": [
		"animation_loop",
		"sort_priority"
	],
	"wuxia_palm/-1": [
		"looping"
	],
	"wuxia_palm/0": [
		"animation_loop",
		"sort_priority"
	],
	"wuxia_palm/1": [
		"animation_loop"
	],
	"wuxia_pierce/-1": [
		"looping"
	],
	"wuxia_pierce/0": [
		"animation_loop",
		"sort_priority"
	],
	"wuxia_dash/-1": [
		"looping"
	],
	"wuxia_dash/0": [
		"animation_loop",
		"sort_priority"
	],
	"wuxia_crush/-1": [
		"looping"
	],
	"wuxia_crush/0": [
		"animation_loop",
		"sort_priority"
	],
	"wuxia_crush/1": [
		"animation_loop"
	],
	"wuxia_needle/-1": [
		"looping"
	],
	"wuxia_needle/0": [
		"animation_loop",
		"sort_priority"
	],
	"wuxia_counter/-1": [
		"looping"
	],
	"wuxia_counter/0": [
		"animation_loop",
		"sort_priority"
	],
	"wuxia_counter/1": [
		"sort_priority",
		"animation_loop"
	],
	"wuxia_acupoint/-1": [
		"looping"
	],
	"wuxia_acupoint/0": [
		"animation_loop",
		"sort_priority"
	],
	"wuxia_smokebomb/-1": [
		"looping"
	],
	"wuxia_smokebomb/0": [
		"animation_loop"
	],
	"wuxia_smokebomb/1": [
		"animation_loop"
	],
	"wuxia_pixelstream/-1": [
		"looping"
	],
	"wuxia_pixelstream/0": [
		"sort_priority"
	],
	"wuxia_returnblade/-1": [
		"looping"
	],
	"wuxia_returnblade/0": [
		"sort_priority"
	],
	"wuxia_groundwave/-1": [
		"looping"
	],
	"wuxia_groundwave/0": [
		"sort_priority"
	],
	"xianxia_sword/-1": [
		"looping"
	],
	"xianxia_sword/0": [
		"animation_loop",
		"animation_fps",
		"sort_priority"
	],
	"xianxia_sword/2": [
		"animation_loop"
	],
	"xianxia_talisman/0": [
		"animation_loop"
	],
	"xianxia_talisman/1": [
		"animation_loop"
	],
	"xianxia_talisman/3": [
		"animation_loop"
	],
	"xianxia_lightning/0": [
		"animation_loop",
		"sort_priority"
	],
	"xianxia_lightning/1": [
		"animation_loop",
		"sort_priority"
	],
	"xianxia_lightning/2": [
		"animation_loop"
	],
	"xianxia_lightning/3": [
		"animation_loop"
	],
	"xianxia_lightning/4": [
		"animation_loop"
	],
	"xianxia_charge/-1": [
		"looping"
	],
	"xianxia_charge/0": [
		"animation_loop"
	],
	"xianxia_charge/1": [
		"animation_loop"
	],
	"xianxia_lotus/-1": [
		"looping"
	],
	"xianxia_lotus/0": [
		"animation_loop",
		"sort_priority"
	],
	"xianxia_lotus/1": [
		"animation_loop"
	],
	"xianxia_seal/-1": [
		"looping"
	],
	"xianxia_seal/0": [
		"animation_loop",
		"sort_priority"
	],
	"xianxia_seal/1": [
		"animation_loop"
	],
	"xianxia_feather/-1": [
		"looping"
	],
	"xianxia_feather/0": [
		"animation_loop",
		"sort_priority"
	],
	"xianxia_feather/1": [
		"sort_priority",
		"animation_loop"
	],
	"xianxia_meridian/-1": [
		"looping"
	],
	"xianxia_meridian/0": [
		"animation_loop",
		"sort_priority"
	],
	"xianxia_meridian/1": [
		"animation_loop"
	],
	"xianxia_blink/0": [
		"secondary",
		"animation_loop",
		"sort_priority"
	],
	"xianxia_blink/1": [
		"secondary",
		"animation_loop",
		"sort_priority"
	],
	"xianxia_blink/2": [
		"secondary",
		"animation_loop"
	],
	"xianxia_bell/0": [
		"animation_loop"
	],
	"xianxia_bell/1": [
		"animation_loop",
		"sort_priority"
	],
	"xianxia_bell/2": [
		"animation_loop"
	],
	"xianxia_arc/-1": [
		"looping"
	],
	"xianxia_arc/0": [
		"sort_priority"
	],
	"xianxia_swordarray/-1": [
		"looping"
	],
	"xianxia_swordarray/0": [
		"sort_priority"
	],
	"xianxia_spiritbutterfly/-1": [
		"looping"
	],
	"xianxia_spiritbutterfly/0": [
		"sort_priority"
	],
	"magic_icefall/0": [
		"animation_loop",
		"sort_priority"
	],
	"magic_icefall/1": [
		"animation_loop"
	],
	"magic_flare/-1": [
		"looping"
	],
	"magic_flare/0": [
		"animation_loop",
		"sort_priority"
	],
	"magic_flare/1": [
		"animation_loop"
	],
	"magic_flare/2": [
		"animation_loop"
	],
	"magic_missile/1": [
		"animation_loop"
	],
	"magic_heal/-1": [
		"looping"
	],
	"magic_heal/0": [
		"animation_loop",
		"sort_priority"
	],
	"magic_heal/1": [
		"sort_priority",
		"animation_loop"
	],
	"magic_frostnova/-1": [
		"looping"
	],
	"magic_frostnova/0": [
		"animation_loop",
		"sort_priority"
	],
	"magic_frostnova/1": [
		"sort_priority",
		"animation_loop"
	],
	"magic_water/0": [
		"animation_loop"
	],
	"magic_water/1": [
		"animation_loop"
	],
	"magic_water/2": [
		"animation_loop"
	],
	"magic_earth/-1": [
		"looping"
	],
	"magic_earth/0": [
		"animation_loop"
	],
	"magic_earth/2": [
		"animation_loop"
	],
	"magic_shadow/-1": [
		"looping"
	],
	"magic_shadow/0": [
		"animation_loop",
		"sort_priority"
	],
	"magic_shadow/1": [
		"animation_loop"
	],
	"magic_briar/-1": [
		"looping"
	],
	"magic_briar/0": [
		"animation_loop"
	],
	"magic_briar/1": [
		"animation_loop"
	],
	"magic_siphon/-1": [
		"looping"
	],
	"magic_siphon/0": [
		"animation_loop",
		"sort_priority"
	],
	"magic_siphon/1": [
		"animation_loop"
	],
	"magic_icecage/-1": [
		"looping"
	],
	"magic_icecage/0": [
		"sort_priority"
	],
	"magic_voidvortex/-1": [
		"looping"
	],
	"magic_voidvortex/0": [
		"sort_priority"
	]
}
