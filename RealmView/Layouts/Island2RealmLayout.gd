extends RealmLayout


func _init() -> void:
	island_texture = preload("res://RealmView/davinci_2048x2048_game_asset_sprite_with_a_transparent_bac.png")
	island_aspect_ratio = 1.000000
	island_view_scale = 0.750000
	island_view_offset = Vector2(0.000000, -0.080000)
	main_lake_edge_points = PackedVector2Array([
		Vector2(0.339095, 0.431686),
		Vector2(0.369477, 0.409936),
		Vector2(0.393225, 0.397952),
		Vector2(0.426643, 0.371251),
		Vector2(0.455322, 0.363627),
		Vector2(0.473365, 0.356748),
		Vector2(0.501445, 0.352757),
		Vector2(0.530066, 0.364916),
		Vector2(0.560236, 0.375307),
		Vector2(0.589852, 0.393468),
		Vector2(0.618670, 0.412579),
		Vector2(0.638435, 0.445283),
		Vector2(0.628463, 0.465113),
		Vector2(0.592327, 0.486912),
		Vector2(0.582675, 0.495347),
		Vector2(0.570141, 0.497772),
		Vector2(0.548769, 0.506064),
		Vector2(0.521058, 0.514888),
		Vector2(0.493196, 0.518242),
		Vector2(0.467227, 0.508823),
		Vector2(0.445242, 0.499956),
		Vector2(0.413658, 0.491148),
		Vector2(0.373548, 0.463829),
		Vector2(0.353655, 0.450327)
	])
	small_lake_definitions = [
		
		
		
	]
	lava_flow_definitions = [
		{
			"points": PackedVector2Array([
				Vector2(0.152410, 0.634000)
			]),
			"widths": PackedFloat32Array([
				3.000000,
				3.000000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.210000,
			"stop_fill": 0.180000,
			"fall_width": 5.500000,
			"fall_length": 150.000000,
			"fall_speed": 150.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.177948, 0.639953)
			]),
			"widths": PackedFloat32Array([
				3.000000,
				3.000000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.300000,
			"stop_fill": 0.280000,
			"fall_width": 5.000000,
			"fall_length": 100.000000,
			"fall_speed": 100.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.491697, 0.482597),
				Vector2(0.471832, 0.503313),
				Vector2(0.454279, 0.538330),
				Vector2(0.436831, 0.551567),
				Vector2(0.399286, 0.580339),
				Vector2(0.412738, 0.602742),
				Vector2(0.340598, 0.656166)
			]),
			"widths": PackedFloat32Array([
				2.000000,
				2.501761,
				3.000000,
				3.000000,
				3.000000,
				7.000000,
				4.000000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.400000,
			"stop_fill": 0.360000,
			"fall_width": 6.500000,
			"fall_length": 220.000000,
			"fall_speed": 220.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.518504, 0.481032),
				Vector2(0.567423, 0.493266),
				Vector2(0.616820, 0.518645),
				Vector2(0.634009, 0.543317),
				Vector2(0.619657, 0.562723),
				Vector2(0.610611, 0.585012),
				Vector2(0.651684, 0.617737),
				Vector2(0.683820, 0.639194)
			]),
			"widths": PackedFloat32Array([
				3.000000,
				4.956635,
				5.500000,
				7.500000,
				7.759313,
				8.000000,
				7.086544,
				9.500000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.600000,
			"stop_fill": 0.550000,
			"fall_width": 9.978083,
			"fall_length": 165.000000,
			"fall_speed": 120.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.273431, 0.741148),
				Vector2(0.273839, 0.740378)
			]),
			"widths": PackedFloat32Array([
				3.000000,
				3.000000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.950000,
			"stop_fill": 0.900000,
			"requires_flow": 5,
			"fall_width": 3.000000,
			"fall_length": 80.000000,
			"fall_speed": 80.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.561058, 0.804192),
				Vector2(0.562109, 0.814893)
			]),
			"widths": PackedFloat32Array([
				4.000000,
				6.000000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.872000,
			"stop_fill": 0.802000,
			"fall_width": 5.000000,
			"fall_length": 150.000000,
			"fall_speed": 120.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.124147, 0.609618),
				Vector2(0.120996, 0.609956)
			]),
			"widths": PackedFloat32Array([
				7.000000,
				9.000000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.550000,
			"stop_fill": 0.500000,
			"fall_width": 5.000000,
			"fall_length": 165.000000,
			"fall_speed": 125.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.443480, 0.482425),
				Vector2(0.406503, 0.496661),
				Vector2(0.349729, 0.527882),
				Vector2(0.328376, 0.562116),
				Vector2(0.250898, 0.599923),
				Vector2(0.236098, 0.674533)
			]),
			"widths": PackedFloat32Array([
				10.000000,
				4.000000,
				4.000000,
				4.000000,
				8.000000,
				10.000000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.650000,
			"stop_fill": 0.600000,
			"fall_width": 9.385029,
			"fall_length": 110.000000,
			"fall_speed": 95.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.526980, 0.495371),
				Vector2(0.581867, 0.478778),
				Vector2(0.610265, 0.470194),
				Vector2(0.629315, 0.464435),
				Vector2(0.669450, 0.485378),
				Vector2(0.700748, 0.487907),
				Vector2(0.724411, 0.508467),
				Vector2(0.753882, 0.512380),
				Vector2(0.772082, 0.512923),
				Vector2(0.826969, 0.541085),
				Vector2(0.831864, 0.557226)
			]),
			"widths": PackedFloat32Array([
				4.000000,
				3.922111,
				3.881812,
				3.854779,
				3.516474,
				3.453737,
				3.387170,
				3.247511,
				3.108422,
				3.000000,
				4.200000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.730000,
			"stop_fill": 0.700000,
			"fall_width": 4.500000,
			"fall_length": 120.000000,
			"fall_speed": 110.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.627642, 0.434642),
				Vector2(0.671677, 0.430129),
				Vector2(0.727259, 0.448973),
				Vector2(0.784745, 0.437198),
				Vector2(0.819878, 0.430793),
				Vector2(0.871527, 0.412239)
			]),
			"widths": PackedFloat32Array([
				2.000000,
				2.542853,
				3.000000,
				5.000000,
				6.000000,
				8.000000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.830000,
			"stop_fill": 0.800000,
			"fall_width": 6.500000,
			"fall_length": 283.542913,
			"fall_speed": 125.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.619275, 0.778750),
				Vector2(0.619462, 0.786569)
			]),
			"widths": PackedFloat32Array([
				2.000000,
				7.000000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.900000,
			"stop_fill": 0.880000,
			"fall_width": 5.000000,
			"fall_length": 170.000000,
			"fall_speed": 125.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.517534, 0.420666),
				Vector2(0.531929, 0.393131),
				Vector2(0.548390, 0.361645),
				Vector2(0.567592, 0.340915),
				Vector2(0.565013, 0.321333),
				Vector2(0.584248, 0.299598),
				Vector2(0.586565, 0.300406)
			]),
			"widths": PackedFloat32Array([
				2.000000,
				2.000000,
				2.000000,
				2.000000,
				2.000000,
				2.000000,
				2.000000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.970000,
			"stop_fill": 0.950000,
			"fall_width": 1.000000,
			"fall_length": 8.000000,
			"fall_speed": 100.000000,
			"fall_z": 4
		},
		{
			"points": PackedVector2Array([
				Vector2(0.500169, 0.458240),
				Vector2(0.390700, 0.394837),
				Vector2(0.330850, 0.362218),
				Vector2(0.297429, 0.360934),
				Vector2(0.261537, 0.340785),
				Vector2(0.232716, 0.345320),
				Vector2(0.192024, 0.351499),
				Vector2(0.130645, 0.340104)
			]),
			"widths": PackedFloat32Array([
				2.000000,
				4.979077,
				3.500000,
				3.500000,
				4.290722,
				4.955866,
				4.665595,
				3.000000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.920000,
			"stop_fill": 0.900000,
			"fall_width": 4.651473,
			"fall_length": 322.807793,
			"fall_speed": 140.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.486864, 0.452806),
				Vector2(0.457581, 0.409618),
				Vector2(0.428735, 0.367075),
				Vector2(0.357934, 0.331278),
				Vector2(0.340353, 0.319705),
				Vector2(0.330375, 0.302865),
				Vector2(0.330533, 0.277706),
				Vector2(0.303607, 0.254174)
			]),
			"widths": PackedFloat32Array([
				2.000000,
				2.251881,
				4.500000,
				5.000000,
				8.500000,
				12.000000,
				8.000000,
				7.500000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.990000,
			"stop_fill": 0.950000,
			"fall_width": 6.500000,
			"fall_length": 160.000000,
			"fall_speed": 120.000000,
			"fall_z": 4
		}
	]
	generator_layout_positions = {
		"atomic_friction": Vector2(0.489935, 0.650831),
		"molecular_agitation": Vector2(0.525799, 0.566110),
		"thermal_furnace": Vector2(0.444881, 0.325206),
		"thermal_compressor": Vector2(0.615829, 0.254067),
		"lava_mite_colony": Vector2(0.730789, 0.561260),
		"matter_furnace": Vector2(0.760803, 0.244336),
		"infernal_forge": Vector2(0.154511, 0.409355)
	}
	brazier_layout_positions = {
		"stability": Vector2(0.435256, 0.158055),
		"density": Vector2(0.095657, 0.286329),
		"integrity": Vector2(0.945670, 0.411214),
		"intensity": Vector2(0.720221, 0.167190),
		"resonance": Vector2(0.878130, 0.223948)
	}
	ash_pile_layout_positions = PackedVector2Array([
		Vector2(0.222089, 0.513287),
		Vector2(0.302196, 0.413386),
		Vector2(0.315779, 0.612038),
		Vector2(0.606588, 0.326932),
		Vector2(0.701130, 0.395803),
		Vector2(0.797868, 0.333606)
	])
