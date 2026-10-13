extends RealmLayout


func _init() -> void:
	island_texture = preload("res://RealmView/davinci_2048x2048_game_asset_sprite_with_a_transparent_bac (2).png")
	island_aspect_ratio = 1.000000
	island_view_scale = 0.750000
	island_view_offset = Vector2(0.000000, -0.090000)
	main_lake_edge_points = PackedVector2Array([
		Vector2(0.363487, 0.437230),
		Vector2(0.369477, 0.417698),
		Vector2(0.377703, 0.379101),
		Vector2(0.412559, 0.367885),
		Vector2(0.444736, 0.351743),
		Vector2(0.466557, 0.353508),
		Vector2(0.484149, 0.362518),
		Vector2(0.513279, 0.344550),
		Vector2(0.541360, 0.362737),
		Vector2(0.560001, 0.370461),
		Vector2(0.586845, 0.398594),
		Vector2(0.598979, 0.428140),
		Vector2(0.596957, 0.449017),
		Vector2(0.569371, 0.472060),
		Vector2(0.543846, 0.481338),
		Vector2(0.522465, 0.488900),
		Vector2(0.492224, 0.555964),
		Vector2(0.462296, 0.494928),
		Vector2(0.442195, 0.491628),
		Vector2(0.421769, 0.477774),
		Vector2(0.390243, 0.454762)
	])
	small_lake_definitions = []
	lava_flow_definitions = [
		{
			"points": PackedVector2Array([
				Vector2(0.805451, 0.700534)
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
				Vector2(0.373085, 0.779674)
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
				Vector2(0.000000, 0.642663),
				Vector2(0.000219, 0.638423)
			]),
			"widths": PackedFloat32Array([
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
				Vector2(0.483025, 0.458854),
				Vector2(0.582450, 0.519754),
				Vector2(0.596313, 0.546644),
				Vector2(0.577525, 0.570485),
				Vector2(0.576240, 0.600536),
				Vector2(0.651684, 0.677617),
				Vector2(0.664972, 0.731233)
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
				Vector2(0.192494, 0.734495),
				Vector2(0.192902, 0.734834)
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
				Vector2(0.000000, 0.650055),
				Vector2(0.000000, 0.648558)
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
				Vector2(0.113060, 0.635123),
				Vector2(0.115453, 0.632134)
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
				Vector2(0.463437, 0.475772),
				Vector2(0.384328, 0.528819),
				Vector2(0.371904, 0.546733),
				Vector2(0.382704, 0.574314),
				Vector2(0.284160, 0.646496),
				Vector2(0.269360, 0.672315)
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
			"fall_width": 8.817729,
			"fall_length": 136.801608,
			"fall_speed": 95.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.000000, 0.646181),
				Vector2(0.000000, 0.657598)
			]),
			"widths": PackedFloat32Array([
				4.000000,
				3.881812
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
				Vector2(0.505682, 0.453494),
				Vector2(0.601583, 0.440862),
				Vector2(0.662208, 0.443148),
				Vector2(0.687199, 0.465614),
				Vector2(0.708410, 0.506635),
				Vector2(0.702699, 0.522583),
				Vector2(0.777180, 0.545906),
				Vector2(0.860902, 0.592692)
			]),
			"widths": PackedFloat32Array([
				2.000000,
				2.281043,
				2.360547,
				2.542853,
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
				Vector2(0.516425, 0.435082),
				Vector2(0.567533, 0.363328),
				Vector2(0.626171, 0.331033),
				Vector2(0.664848, 0.318973),
				Vector2(0.679220, 0.299547),
				Vector2(0.681791, 0.266619),
				Vector2(0.709827, 0.254398),
				Vector2(0.742664, 0.247879),
				Vector2(0.769505, 0.228328)
			]),
			"widths": PackedFloat32Array([
				2.000000,
				2.000000,
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
				Vector2(0.018981, 0.645643),
				Vector2(0.000000, 0.649884)
			]),
			"widths": PackedFloat32Array([
				2.000000,
				4.979077
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
				Vector2(0.482429, 0.457242),
				Vector2(0.386604, 0.382600),
				Vector2(0.300281, 0.349020),
				Vector2(0.281591, 0.323031),
				Vector2(0.276047, 0.291776),
				Vector2(0.247379, 0.272161),
				Vector2(0.199387, 0.248629)
			]),
			"widths": PackedFloat32Array([
				2.000000,
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
		"atomic_friction": Vector2(0.656244, 0.370280),
		"molecular_agitation": Vector2(0.336207, 0.229005),
		"thermal_furnace": Vector2(0.283006, 0.533679),
		"thermal_compressor": Vector2(0.615829, 0.254067),
		"lava_mite_colony": Vector2(0.716375, 0.598963),
		"matter_furnace": Vector2(0.177612, 0.462789),
		"infernal_forge": Vector2(0.768747, 0.275178)
	}
	brazier_layout_positions = {
		"stability": Vector2(0.247880, 0.088195),
		"density": Vector2(0.337360, 0.074529),
		"integrity": Vector2(0.886908, 0.222701),
		"intensity": Vector2(0.629306, 0.076260),
		"resonance": Vector2(0.812715, 0.108623)
	}
	ash_pile_layout_positions = PackedVector2Array([
		Vector2(0.212111, 0.550990),
		Vector2(0.326588, 0.385663),
		Vector2(0.487632, 0.695205),
		Vector2(0.789529, 0.275922),
		Vector2(0.662325, 0.589860),
		Vector2(0.716930, 0.364655)
	])
