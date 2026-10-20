extends RealmLayout


func _init() -> void:
	island_texture = preload("res://RealmView/Red_Island_1.png")
	island_aspect_ratio = 1.000000
	island_view_scale = 0.800000
	island_view_offset = Vector2(-0.010000, 0.000000)
	main_lake_edge_points = PackedVector2Array([
		Vector2(0.386321, 0.426954),
		Vector2(0.394696, 0.403395),
		Vector2(0.412883, 0.387226),
		Vector2(0.476439, 0.367683),
		Vector2(0.507387, 0.369669),
		Vector2(0.537920, 0.370126),
		Vector2(0.576394, 0.383236),
		Vector2(0.603684, 0.398441),
		Vector2(0.613697, 0.417058),
		Vector2(0.616102, 0.435483),
		Vector2(0.590449, 0.454170),
		Vector2(0.561137, 0.469424),
		Vector2(0.503250, 0.483048),
		Vector2(0.476156, 0.477384),
		Vector2(0.425414, 0.461774),
		Vector2(0.398153, 0.443701)
	])
	main_lake_center_position = Vector2(0.504975, 0.474347)
	small_lake_definitions = [
		{
			"name": "Upper Reservoir",
			"points": PackedVector2Array([
				Vector2(0.255944, 0.463427),
				Vector2(0.270401, 0.453935),
				Vector2(0.275511, 0.445681),
				Vector2(0.253719, 0.439613),
				Vector2(0.227799, 0.440944),
				Vector2(0.204867, 0.449481),
				Vector2(0.219318, 0.457413)
			]),
			"start_fill": 0.150000,
			"full_fill": 0.500000
		},
		{
			"name": "Lower Reservoir",
			"points": PackedVector2Array([
				Vector2(0.558201, 0.641377),
				Vector2(0.566840, 0.651727),
				Vector2(0.576235, 0.654773),
				Vector2(0.592404, 0.657411),
				Vector2(0.602839, 0.647827),
				Vector2(0.608012, 0.631854),
				Vector2(0.598636, 0.624098),
				Vector2(0.587436, 0.619489),
				Vector2(0.569100, 0.616702),
				Vector2(0.559326, 0.630040)
			]),
			"start_fill": 0.550000,
			"full_fill": 0.950000
		},
		{
			"name": "Outer Reservoir",
			"points": PackedVector2Array([
				Vector2(0.839742, 0.404609),
				Vector2(0.851813, 0.401106),
				Vector2(0.865976, 0.404109),
				Vector2(0.865113, 0.414465),
				Vector2(0.849202, 0.419401),
				Vector2(0.838967, 0.417052),
				Vector2(0.834208, 0.411430)
			]),
			"start_fill": 0.700000,
			"full_fill": 0.900000
		}
	]
	lava_flow_definitions = [
		{
			"points": PackedVector2Array([]),
			"widths": PackedFloat32Array([]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.210000,
			"stop_fill": 0.180000,
			"fall_width": 5.500000,
			"fall_length": 150.000000,
			"fall_speed": 150.000000,
			"fall_z": 7,
			"has_fall": false
		},
		{
			"points": PackedVector2Array([
				Vector2(0.378296, 0.776325)
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
			"points": PackedVector2Array([]),
			"widths": PackedFloat32Array([]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.400000,
			"stop_fill": 0.360000,
			"fall_width": 6.500000,
			"fall_length": 220.000000,
			"fall_speed": 220.000000,
			"fall_z": 7,
			"has_fall": false
		},
		{
			"points": PackedVector2Array([
				Vector2(0.501433, 0.461747),
				Vector2(0.568386, 0.476776),
				Vector2(0.589433, 0.501951),
				Vector2(0.605825, 0.506439),
				Vector2(0.623834, 0.508391),
				Vector2(0.652072, 0.526291),
				Vector2(0.652384, 0.544360),
				Vector2(0.655320, 0.570233),
				Vector2(0.690239, 0.599561),
				Vector2(0.732913, 0.632942)
			]),
			"widths": PackedFloat32Array([
				3.000000,
				8.555643,
				9.211363,
				9.100703,
				7.500000,
				13.000000,
				15.500000,
				14.500000,
				12.208052,
				11.500000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.600000,
			"stop_fill": 0.550000,
			"fall_width": 10.436774,
			"fall_length": 165.000000,
			"fall_speed": 120.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([]),
			"widths": PackedFloat32Array([]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.950000,
			"stop_fill": 0.900000,
			"requires_flow": 5,
			"fall_width": 3.000000,
			"fall_length": 80.000000,
			"fall_speed": 80.000000,
			"fall_z": 7,
			"has_fall": false
		},
		{
			"points": PackedVector2Array([]),
			"widths": PackedFloat32Array([]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.872000,
			"stop_fill": 0.802000,
			"fall_width": 5.000000,
			"fall_length": 150.000000,
			"fall_speed": 120.000000,
			"fall_z": 7,
			"has_fall": false
		},
		{
			"points": PackedVector2Array([]),
			"widths": PackedFloat32Array([]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.550000,
			"stop_fill": 0.500000,
			"fall_width": 5.000000,
			"fall_length": 165.000000,
			"fall_speed": 125.000000,
			"fall_z": 7,
			"has_fall": false
		},
		{
			"points": PackedVector2Array([]),
			"widths": PackedFloat32Array([]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.650000,
			"stop_fill": 0.600000,
			"fall_width": 4.000000,
			"fall_length": 110.000000,
			"fall_speed": 95.000000,
			"fall_z": 7,
			"has_fall": false
		},
		{
			"points": PackedVector2Array([]),
			"widths": PackedFloat32Array([]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.730000,
			"stop_fill": 0.700000,
			"fall_width": 4.500000,
			"fall_length": 120.000000,
			"fall_speed": 110.000000,
			"fall_z": 7,
			"has_fall": false
		},
		{
			"points": PackedVector2Array([
				Vector2(0.570682, 0.427610),
				Vector2(0.634773, 0.444533),
				Vector2(0.656431, 0.452938),
				Vector2(0.674185, 0.456269),
				Vector2(0.692330, 0.450235),
				Vector2(0.715395, 0.444769),
				Vector2(0.732665, 0.445363),
				Vector2(0.760120, 0.461114),
				Vector2(0.790021, 0.476600),
				Vector2(0.817085, 0.471851),
				Vector2(0.856197, 0.460648),
				Vector2(0.872174, 0.465119),
				Vector2(0.903641, 0.479453),
				Vector2(0.931638, 0.489683)
			]),
			"widths": PackedFloat32Array([
				2.000000,
				3.376148,
				5.515121,
				3.623915,
				4.774681,
				4.372450,
				5.000000,
				5.915732,
				6.500000,
				6.289102,
				7.298000,
				7.500000,
				7.032111,
				9.500000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.830000,
			"stop_fill": 0.800000,
			"fall_width": 7.658040,
			"fall_length": 177.294120,
			"fall_speed": 125.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.501972, 0.464026),
				Vector2(0.444105, 0.439859),
				Vector2(0.390161, 0.468475),
				Vector2(0.351258, 0.490649),
				Vector2(0.326745, 0.491785),
				Vector2(0.275468, 0.495719),
				Vector2(0.252857, 0.517020),
				Vector2(0.235908, 0.519975),
				Vector2(0.179312, 0.510453),
				Vector2(0.119722, 0.526714)
			]),
			"widths": PackedFloat32Array([
				3.000000,
				5.502478,
				4.041827,
				4.976690,
				5.422820,
				7.500000,
				5.630626,
				4.500000,
				7.000000,
				9.500000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.900000,
			"stop_fill": 0.880000,
			"fall_width": 5.991766,
			"fall_length": 170.000000,
			"fall_speed": 125.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.528734, 0.450736),
				Vector2(0.593155, 0.496938),
				Vector2(0.627019, 0.511861),
				Vector2(0.666208, 0.532690),
				Vector2(0.688437, 0.538379),
				Vector2(0.717331, 0.540786),
				Vector2(0.735197, 0.557143),
				Vector2(0.751113, 0.568412),
				Vector2(0.752746, 0.584093),
				Vector2(0.766584, 0.597421),
				Vector2(0.780181, 0.612698)
			]),
			"widths": PackedFloat32Array([
				0.000000,
				0.000000,
				0.000000,
				2.000000,
				2.000000,
				5.000000,
				4.000000,
				7.500000,
				6.500000,
				6.000000,
				4.500000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.970000,
			"stop_fill": 0.950000,
			"fall_width": 6.000000,
			"fall_length": 230.000000,
			"fall_speed": 100.000000,
			"fall_z": 7,
			"has_fall": true
		},
		{
			"points": PackedVector2Array([
				Vector2(0.503457, 0.468545),
				Vector2(0.482386, 0.453560),
				Vector2(0.462294, 0.463452),
				Vector2(0.411153, 0.504116),
				Vector2(0.368056, 0.528381),
				Vector2(0.378781, 0.562125),
				Vector2(0.365400, 0.575294),
				Vector2(0.327418, 0.599172),
				Vector2(0.309192, 0.607071),
				Vector2(0.267462, 0.633587)
			]),
			"widths": PackedFloat32Array([
				2.000000,
				5.968855,
				9.000000,
				5.500000,
				13.500000,
				13.000000,
				7.396801,
				12.243929,
				17.257956,
				15.000000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.920000,
			"stop_fill": 0.900000,
			"fall_width": 14.861638,
			"fall_length": 140.000000,
			"fall_speed": 140.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([]),
			"widths": PackedFloat32Array([]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.990000,
			"stop_fill": 0.950000,
			"fall_width": 6.500000,
			"fall_length": 160.000000,
			"fall_speed": 120.000000,
			"fall_z": 4,
			"has_fall": false
		},
		{
			"points": PackedVector2Array([
				Vector2(0.512515, 0.444841),
				Vector2(0.495827, 0.531175),
				Vector2(0.504158, 0.546769),
				Vector2(0.537733, 0.563262),
				Vector2(0.555981, 0.575181),
				Vector2(0.569031, 0.628059),
				Vector2(0.576877, 0.661416),
				Vector2(0.585012, 0.677195)
			]),
			"widths": PackedFloat32Array([
				3.000000,
				3.000000,
				5.000000,
				7.000000,
				3.500000,
				3.421324,
				3.365057,
				3.000000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.500000,
			"stop_fill": 0.450000,
			"has_fall": true,
			"fall_width": 4.000000,
			"fall_length": 60.000000,
			"fall_speed": 100.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.518234, 0.447539),
				Vector2(0.504261, 0.490000),
				Vector2(0.488900, 0.528862),
				Vector2(0.511654, 0.553019),
				Vector2(0.505608, 0.571704),
				Vector2(0.474571, 0.591808),
				Vector2(0.483876, 0.619550),
				Vector2(0.471732, 0.670388),
				Vector2(0.459173, 0.689553)
			]),
			"widths": PackedFloat32Array([
				9.500000,
				12.183682,
				7.000000,
				9.000000,
				5.500000,
				4.500000,
				0.000000,
				0.000000,
				8.500000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.500000,
			"stop_fill": 0.450000,
			"has_fall": true,
			"fall_width": 9.496457,
			"fall_length": 60.000000,
			"fall_speed": 100.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([]),
			"widths": PackedFloat32Array([]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.500000,
			"stop_fill": 0.450000,
			"has_fall": false,
			"fall_width": 4.000000,
			"fall_length": 60.000000,
			"fall_speed": 100.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.463948, 0.411792),
				Vector2(0.577229, 0.451919),
				Vector2(0.738918, 0.560056),
				Vector2(0.767096, 0.567658),
				Vector2(0.793547, 0.571876),
				Vector2(0.813271, 0.581806),
				Vector2(0.821896, 0.585958)
			]),
			"widths": PackedFloat32Array([
				0.000000,
				0.000000,
				0.000000,
				5.000000,
				3.500000,
				4.000000,
				4.000000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.500000,
			"stop_fill": 0.450000,
			"has_fall": true,
			"fall_width": 4.000000,
			"fall_length": 60.000000,
			"fall_speed": 100.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.471502, 0.420005),
				Vector2(0.879363, 0.468545),
				Vector2(0.888767, 0.465650),
				Vector2(0.934327, 0.445817),
				Vector2(0.886623, 0.432950),
				Vector2(0.907333, 0.419260),
				Vector2(0.937644, 0.406953)
			]),
			"widths": PackedFloat32Array([
				0.000000,
				0.000000,
				2.738204,
				3.000000,
				3.000000,
				3.000000,
				3.000000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.500000,
			"stop_fill": 0.450000,
			"has_fall": false,
			"fall_width": 4.000000,
			"fall_length": 60.000000,
			"fall_speed": 100.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.671584, 0.389726),
				Vector2(0.692015, 0.394545),
				Vector2(0.713880, 0.379704),
				Vector2(0.729138, 0.370977),
				Vector2(0.762358, 0.379203),
				Vector2(0.794991, 0.371634),
				Vector2(0.804516, 0.377634),
				Vector2(0.845342, 0.375315),
				Vector2(0.863305, 0.369852)
			]),
			"widths": PackedFloat32Array([
				3.000000,
				3.000000,
				3.000000,
				3.000000,
				10.000000,
				3.000000,
				10.000000,
				5.830746,
				4.000000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.500000,
			"stop_fill": 0.450000,
			"has_fall": false,
			"fall_width": 4.000000,
			"fall_length": 60.000000,
			"fall_speed": 100.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.682624, 0.317435),
				Vector2(0.648557, 0.319889),
				Vector2(0.613383, 0.309755),
				Vector2(0.630899, 0.334280),
				Vector2(0.608583, 0.348700),
				Vector2(0.577227, 0.361802),
				Vector2(0.562662, 0.377583)
			]),
			"widths": PackedFloat32Array([
				23.500000,
				31.156113,
				22.621140,
				19.354433,
				10.947275,
				8.220828,
				3.000000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.500000,
			"stop_fill": 0.450000,
			"has_fall": false,
			"fall_width": 4.000000,
			"fall_length": 60.000000,
			"fall_speed": 100.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([]),
			"widths": PackedFloat32Array([]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.500000,
			"stop_fill": 0.450000,
			"has_fall": false,
			"fall_width": 4.000000,
			"fall_length": 60.000000,
			"fall_speed": 100.000000,
			"fall_z": 7
		}
	]
	generator_layout_positions = {
		"atomic_friction": Vector2(0.637013, 0.363051),
		"molecular_agitation": Vector2(0.127631, 0.298388),
		"thermal_furnace": Vector2(0.400914, 0.224192),
		"thermal_compressor": Vector2(0.615829, 0.254067),
		"lava_mite_colony": Vector2(0.333447, 0.358992),
		"matter_furnace": Vector2(0.535087, 0.292343),
		"infernal_forge": Vector2(0.680351, 0.150641)
	}
	brazier_layout_positions = {
		"stability": Vector2(0.181796, 0.551186),
		"density": Vector2(0.282722, 0.235923),
		"integrity": Vector2(0.665269, 0.639427),
		"intensity": Vector2(0.955527, 0.419369),
		"resonance": Vector2(0.765687, 0.185286)
	}
	ash_pile_layout_positions = PackedVector2Array([
		Vector2(0.736200, 0.327285),
		Vector2(0.238623, 0.352611),
		Vector2(0.331100, 0.447621),
		Vector2(0.601057, 0.569350),
		Vector2(0.719097, 0.485330),
		Vector2(0.755956, 0.415255)
	])
	matter_pile_layout_positions = PackedVector2Array([
		Vector2(0.363209, 0.224546),
		Vector2(0.436598, 0.236501),
		Vector2(0.439673, 0.206833),
		Vector2(0.407596, 0.194389)
	])
	smoke_emitter_definitions = []
