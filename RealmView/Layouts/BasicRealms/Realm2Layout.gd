extends RealmLayout


func _init() -> void:
	island_texture = preload("res://RealmView/davinci_2048x2048_game_asset_sprite_with_a_transparent_bac.png")
	island_aspect_ratio = 1.000000
	island_view_scale = 0.750000
	island_view_offset = Vector2(0.000000, -0.080000)
	main_lake_edge_points = PackedVector2Array([
		Vector2(0.351291, 0.453864),
		Vector2(0.373912, 0.443203),
		Vector2(0.409856, 0.416803),
		Vector2(0.443274, 0.408953),
		Vector2(0.470844, 0.402438),
		Vector2(0.485561, 0.397777),
		Vector2(0.511424, 0.405984),
		Vector2(0.532283, 0.411490),
		Vector2(0.551366, 0.421881),
		Vector2(0.555481, 0.428953),
		Vector2(0.586517, 0.422559),
		Vector2(0.587433, 0.420887),
		Vector2(0.587440, 0.427411),
		Vector2(0.579022, 0.432576),
		Vector2(0.604149, 0.459364),
		Vector2(0.619131, 0.473413),
		Vector2(0.629242, 0.483149),
		Vector2(0.612587, 0.507952),
		Vector2(0.567923, 0.536583),
		Vector2(0.553204, 0.545984),
		Vector2(0.522167, 0.550373),
		Vector2(0.489870, 0.559271),
		Vector2(0.446161, 0.555397),
		Vector2(0.419741, 0.542094),
		Vector2(0.388157, 0.531068),
		Vector2(0.344721, 0.503749),
		Vector2(0.321502, 0.480267)
	])
	main_lake_center_position = Vector2(0.483899, 0.520762)
	small_lake_definitions = []
	lava_flow_definitions = [
		{
			"points": PackedVector2Array([
				Vector2(0.159062, 0.689445)
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
				Vector2(0.356454, 0.861733)
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
				Vector2(0.469522, 0.505884),
				Vector2(0.437461, 0.586480),
				Vector2(0.412147, 0.602646),
				Vector2(0.381395, 0.624754),
				Vector2(0.392634, 0.653526),
				Vector2(0.362845, 0.669276),
				Vector2(0.326185, 0.704957)
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
				Vector2(0.504091, 0.504319),
				Vector2(0.569145, 0.545259),
				Vector2(0.598530, 0.569931),
				Vector2(0.617440, 0.584901),
				Vector2(0.603959, 0.603863),
				Vector2(0.592921, 0.632152),
				Vector2(0.662754, 0.687986)
			]),
			"widths": PackedFloat32Array([
				3.000000,
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
				Vector2(0.259018, 0.811009),
				Vector2(0.262752, 0.809130)
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
				Vector2(0.578798, 0.427167),
				Vector2(0.633068, 0.397947)
			]),
			"widths": PackedFloat32Array([
				6.000000,
				8.000000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.872000,
			"stop_fill": 0.802000,
			"fall_width": 1.000000,
			"fall_length": 8.000000,
			"fall_speed": 120.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.545464, 0.848031),
				Vector2(0.550074, 0.849478)
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
				Vector2(0.452350, 0.502385),
				Vector2(0.324457, 0.586482),
				Vector2(0.313141, 0.609940),
				Vector2(0.233026, 0.644175),
				Vector2(0.223180, 0.683090),
				Vector2(0.221684, 0.717780)
			]),
			"widths": PackedFloat32Array([
				10.000000,
				6.500000,
				5.500000,
				7.000000,
				8.000000,
				10.000000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.650000,
			"stop_fill": 0.600000,
			"fall_width": 10.971237,
			"fall_length": 146.763877,
			"fall_speed": 95.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.507023, 0.493153),
				Vector2(0.619135, 0.511223),
				Vector2(0.649272, 0.530969),
				Vector2(0.680537, 0.528625),
				Vector2(0.687443, 0.538916),
				Vector2(0.695584, 0.549496),
				Vector2(0.718403, 0.555627),
				Vector2(0.756560, 0.559497),
				Vector2(0.803686, 0.582114),
				Vector2(0.817451, 0.604909)
			]),
			"widths": PackedFloat32Array([
				4.000000,
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
				Vector2(0.522313, 0.492305),
				Vector2(0.589387, 0.488545),
				Vector2(0.608989, 0.485286),
				Vector2(0.651720, 0.478921),
				Vector2(0.710628, 0.498873),
				Vector2(0.762571, 0.484881),
				Vector2(0.812659, 0.474937),
				Vector2(0.837619, 0.455189)
			]),
			"widths": PackedFloat32Array([
				2.000000,
				2.281043,
				2.360547,
				4.042853,
				3.000000,
				5.000000,
				5.411957,
				6.000000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.830000,
			"stop_fill": 0.800000,
			"fall_width": 7.674884,
			"fall_length": 283.542913,
			"fall_speed": 125.000000,
			"fall_z": 4
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
				Vector2(0.516425, 0.430646),
				Vector2(0.534146, 0.404220),
				Vector2(0.552866, 0.387725),
				Vector2(0.550607, 0.363863),
				Vector2(0.562048, 0.355330),
				Vector2(0.565499, 0.343653)
			]),
			"widths": PackedFloat32Array([
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
				Vector2(0.455820, 0.510358),
				Vector2(0.394026, 0.471351),
				Vector2(0.365221, 0.433187),
				Vector2(0.314060, 0.409725),
				Vector2(0.281494, 0.401774),
				Vector2(0.224955, 0.388567),
				Vector2(0.169849, 0.395855),
				Vector2(0.122884, 0.373371)
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
			"fall_z": 4
		},
		{
			"points": PackedVector2Array([
				Vector2(0.471342, 0.496053),
				Vector2(0.425409, 0.456896),
				Vector2(0.404501, 0.405574),
				Vector2(0.308200, 0.356298),
				Vector2(0.313744, 0.330587),
				Vector2(0.299489, 0.306537),
				Vector2(0.283650, 0.292985)
			]),
			"widths": PackedFloat32Array([
				2.000000,
				4.500000,
				5.000000,
				8.000000,
				10.000000,
				6.500000,
				6.000000
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
		"atomic_friction": Vector2(0.538719, 0.596495),
		"molecular_agitation": Vector2(0.866179, 0.508447),
		"thermal_furnace": Vector2(0.444881, 0.325206),
		"thermal_compressor": Vector2(0.615829, 0.254067),
		"lava_mite_colony": Vector2(0.721919, 0.598963),
		"matter_furnace": Vector2(0.177612, 0.462789),
		"infernal_forge": Vector2(0.768747, 0.275178)
	}
	brazier_layout_positions = {
		"stability": Vector2(0.204640, 0.260074),
		"density": Vector2(0.081244, 0.328467),
		"integrity": Vector2(0.861407, 0.265948),
		"intensity": Vector2(0.410886, 0.197130),
		"resonance": Vector2(0.702951, 0.206206)
	}
	ash_pile_layout_positions = PackedVector2Array([
		Vector2(0.212111, 0.550990),
		Vector2(0.313283, 0.432237),
		Vector2(0.310235, 0.645305),
		Vector2(0.530086, 0.280358),
		Vector2(0.767654, 0.522217),
		Vector2(0.760171, 0.376853)
	])

	matter_pile_layout_positions = PackedVector2Array([
		Vector2(0.230000, 0.560000),
		Vector2(0.510000, 0.610000),
		Vector2(0.780000, 0.560000)
	])
