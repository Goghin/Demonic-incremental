
extends RealmLayout


func _init() -> void:
	island_texture = preload("res://RealmView/infernal_island.png")

	lava_flow_definitions = [
		# 1 — disabled
		{
			"points": PackedVector2Array([
				Vector2(0.671295, 0.658396)
			]),
			"widths": PackedFloat32Array([3.0, 3.0]),
			"speed": 25.0,
			"thickness": 1.0,
			"flow_z": 6,
			"start_fill": 0.18,
			"stop_fill": 0.21,
			"fall_width": 5.5,
			"fall_length": 150.0,
			"fall_speed": 150.0,
			"fall_z": 7
		},

		# 2 — disabled
		{
			"points": PackedVector2Array([
				Vector2(0.387498, 0.625537)
			]),
			"widths": PackedFloat32Array([3.0, 3.0]),
			"speed": 25.0,
			"thickness": 1.0,
			"flow_z": 6,
			"start_fill": 0.28,
			"stop_fill": 0.3,
			"fall_width": 5.0,
			"fall_length": 100.0,
			"fall_speed": 100.0,
			"fall_z": 7
		},

		# 3 — disabled
		{
			"points": PackedVector2Array([
				Vector2(0.452891, 0.413845),
				Vector2(0.415473, 0.441856),
				Vector2(0.430331, 0.486083),
				Vector2(0.410521, 0.536208),
				Vector2(0.420426, 0.595177)
			]),
			"widths": PackedFloat32Array([2.0, 3.0, 3.0, 7.0, 8.0]),
			"speed": 25.0,
			"thickness": 1.0,
			"flow_z": 6,
			"start_fill": 0.36,
			"stop_fill": 0.40,
			"fall_width": 6.5,
			"fall_length": 220.0,
			"fall_speed": 220.0,
			"fall_z": 7
		},

		# 4 — disabled
		{
			"points": PackedVector2Array([
				Vector2(0.575049, 0.443330),
				Vector2(0.623472, 0.474289),
				Vector2(0.622922, 0.506723),
				Vector2(0.638329, 0.531785),
				Vector2(0.633927, 0.584858)
			]),
			"widths": PackedFloat32Array([3.0, 4.0, 5.0, 6.0, 8.0]),
			"speed": 25.0,
			"thickness": 1.0,
			"flow_z": 6,
			"start_fill": 0.55,
			"stop_fill": 0.6,
			"fall_width": 5.5,
			"fall_length": 165.0,
			"fall_speed": 120.0,
			"fall_z": 7
		},

		# 5 — active
		{
			"points": PackedVector2Array([
				Vector2(0.581658, 0.560398),
				Vector2(0.574305, 0.582914)
			]),
			"widths": PackedFloat32Array([3.0, 3.0]),
			"speed": 25.0,
			"thickness": 1.0,
			"flow_z": 6,
			"start_fill": 0.9,
			"stop_fill": 0.95,
			"requires_flow": 5,
			"fall_width": 3.0,
			"fall_length": 80.0,
			"fall_speed": 80.0,
			"fall_z": 7
		},

		# 6 — active
		{
			"points": PackedVector2Array([
				Vector2(0.573254, 0.512552),
				Vector2(0.574305, 0.542104),
				Vector2(0.596365, 0.578692)
			]),
			"widths": PackedFloat32Array([4.0, 6.0, 9.0]),
			"speed": 25.0,
			"thickness": 1.0,
			"flow_z": 6,
			"start_fill": 0.802,
			"stop_fill": 0.872,
			"fall_width": 5.0,
			"fall_length": 150.0,
			"fall_speed": 120.0,
			"fall_z": 7
		},

		# 7 — disabled
		{
			"points": PackedVector2Array([
				Vector2(0.478710, 0.433747),
				Vector2(0.456124, 0.483000),
				Vector2(0.472407, 0.523810),
				Vector2(0.454548, 0.551955),
				Vector2(0.461376, 0.574471)
			]),
			"widths": PackedFloat32Array([4.0, 5.0, 6.0, 7.0, 9.0]),
			"speed": 25.0,
			"thickness": 1.0,
			"flow_z": 6,
			"start_fill": 0.5,
			"stop_fill": 0.55,
			"fall_width": 5.0,
			"fall_length": 165.0,
			"fall_speed": 125.0,
			"fall_z": 7
		},

		# 8 — disabled
		{
			"points": PackedVector2Array([
				Vector2(0.334825, 0.507930),
				Vector2(0.327783, 0.511077),
				Vector2(0.313700, 0.525238),
				Vector2(0.308419, 0.529958),
				Vector2(0.300791, 0.537825),
				Vector2(0.283773, 0.561426)
			]),
			"widths": PackedFloat32Array([10.0, 4.0, 3.0, 4.0, 8.0, 4.0]),
			"speed": 25.0,
			"thickness": 1.0,
			"flow_z": 6,
			"start_fill": 0.6,
			"stop_fill": 0.65,
			"fall_width": 4.0,
			"fall_length": 110.0,
			"fall_speed": 95.0,
			"fall_z": 7
		},

		# 9 — disabled
		{
			"points": PackedVector2Array([
				Vector2(0.702159, 0.469866),
				Vector2(0.691704, 0.511145),
				Vector2(0.704360, 0.553899)
			]),
			"widths": PackedFloat32Array([4.0, 3.0, 4.2]),
			"speed": 25.0,
			"thickness": 1.0,
			"flow_z": 6,
			"start_fill": 0.7,
			"stop_fill": 0.73,
			"fall_width": 4.5,
			"fall_length": 120.0,
			"fall_speed": 110.0,
			"fall_z": 7
		},

		# 10 — disabled
		{
			"points": PackedVector2Array([
				Vector2(0.582184, 0.437969),
				Vector2(0.645213, 0.432340),
				Vector2(0.698264, 0.460485),
				Vector2(0.734506, 0.513960),
				Vector2(0.782829, 0.515367)
			]),
			"widths": PackedFloat32Array([2.0, 3.0, 5.0, 6.0, 8.0]),
			"speed": 25.0,
			"thickness": 1.0,
			"flow_z": 6,
			"start_fill": 0.8,
			"stop_fill": 0.83,
			"fall_width": 6.5,
			"fall_length": 210.0,
			"fall_speed": 125.0,
			"fall_z": 7
		},

		# 11 — disabled
		{
			"points": PackedVector2Array([
				Vector2(0.442987, 0.387309),
				Vector2(0.405569, 0.379937),
				Vector2(0.374754, 0.405000),
				Vector2(0.340638, 0.400577),
				Vector2(0.335686, 0.450701),
				Vector2(0.292215, 0.431536),
				Vector2(0.269104, 0.494929)
			]),
			"widths": PackedFloat32Array([2.0, 3.0, 3.0, 5.0, 6.0, 5.0, 7.0]),
			"speed": 25.0,
			"thickness": 1.0,
			"flow_z": 6,
			"start_fill": 0.88,
			"stop_fill": 0.9,
			"fall_width": 5.0,
			"fall_length": 170.0,
			"fall_speed": 125.0,
			"fall_z": 7
		},

		# 12 — disabled
		{
			"points": PackedVector2Array([
				Vector2(0.556340, 0.356350),
				Vector2(0.581652, 0.315071),
				Vector2(0.608615, 0.325390),
				Vector2(0.657038, 0.322442),
				Vector2(0.679599, 0.297380),
				Vector2(0.718117, 0.279689),
				Vector2(0.740678, 0.273792)
			]),
			"widths": PackedFloat32Array([2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0]),
			"speed": 25.0,
			"thickness": 1.0,
			"flow_z": 6,
			"start_fill": 0.95,
			"stop_fill": 0.97,
			"fall_width": 6.0,
			"fall_length": 230.0,
			"fall_speed": 100.0,
			"fall_z": 4
		},

		# 13
		{
			"points": PackedVector2Array([
				Vector2(0.289510, 0.429409),
				Vector2(0.261000, 0.424316),
				Vector2(0.228688, 0.442992),
				Vector2(0.184973, 0.482043)
			]),
			"widths": PackedFloat32Array([2.0, 3.0, 3.0, 4.0]),
			"speed": 25.0,
			"thickness": 1.0,
			"flow_z": 6,
			"start_fill": 0.9,
			"stop_fill": 0.92,
			"fall_width": 4.5,
			"fall_length": 140.0,
			"fall_speed": 140.0,
			"fall_z": 7
		},

		# 14
		{
			"points": PackedVector2Array([
				Vector2(0.418123, 0.353005),
				Vector2(0.387712, 0.336026),
				Vector2(0.371239, 0.347911),
				Vector2(0.337027, 0.324141),
				Vector2(0.275572, 0.317350),
				Vector2(0.257199, 0.313954),
				Vector2(0.209682, 0.330933),
				Vector2(0.127319, 0.346213)
			]),
			"widths": PackedFloat32Array([2.0, 2.5, 3.5, 4.0, 2.6, 0.0, 0.0, 4.5]),
			"speed": 25.0,
			"thickness": 1.0,
			"flow_z": 6,
			"start_fill": 0.95,
			"stop_fill": 0.99,
			"fall_width": 6.5,
			"fall_length": 160.0,
			"fall_speed": 120.0,
			"fall_z": 4
		}
	]

	main_lake_edge_points = PackedVector2Array([
		Vector2(0.461055, 0.342974),
		Vector2(0.502262, 0.341350),
		Vector2(0.516200, 0.352719),
		Vector2(0.531956, 0.354343),
		Vector2(0.536804, 0.346222),
		Vector2(0.554377, 0.339726),
		Vector2(0.570739, 0.338101),
		Vector2(0.567709, 0.362464),
		Vector2(0.576799, 0.370585),
		Vector2(0.586495, 0.390075),
		Vector2(0.596797, 0.386827),
		Vector2(0.602857, 0.391699),
		Vector2(0.605281, 0.412814),
		Vector2(0.600433, 0.419311),
		Vector2(0.599827, 0.427431),
		Vector2(0.604675, 0.435552),
		Vector2(0.605887, 0.443673),
		Vector2(0.588313, 0.463163),
		Vector2(0.580435, 0.464788),
		Vector2(0.577405, 0.468036),
		Vector2(0.571345, 0.461539),
		Vector2(0.559831, 0.466412),
		Vector2(0.553165, 0.468036),
		Vector2(0.544681, 0.461539),
		Vector2(0.525896, 0.463163),
		Vector2(0.524684, 0.458291),
		Vector2(0.516806, 0.458291),
		Vector2(0.514988, 0.464788),
		Vector2(0.506504, 0.464788),
		Vector2(0.501656, 0.458291),
		Vector2(0.478628, 0.451794),
		Vector2(0.474992, 0.456667),
		Vector2(0.470750, 0.455043),
		Vector2(0.467114, 0.461539),
		Vector2(0.464085, 0.459915),
		Vector2(0.468326, 0.451794),
		Vector2(0.465296, 0.440425),
		Vector2(0.443481, 0.429056),
		Vector2(0.444693, 0.417686),
		Vector2(0.428937, 0.412814),
		Vector2(0.418029, 0.398196),
		Vector2(0.410151, 0.373833),
		Vector2(0.416817, 0.359216),
		Vector2(0.434997, 0.352719)
	])

	small_lake_definitions = [
		{
			"name": "Upper Reservoir",
			"points": PackedVector2Array([
				Vector2(0.333859, 0.526188),
				Vector2(0.338294, 0.519396),
				Vector2(0.343363, 0.527886),
				Vector2(0.347797, 0.512605),
				Vector2(0.346530, 0.507511),
				Vector2(0.339561, 0.500720),
				Vector2(0.334493, 0.500720),
				Vector2(0.329424, 0.505814),
				Vector2(0.329424, 0.514303),
				Vector2(0.333226, 0.522792)
			]),
			"start_fill": 0.15,
			"full_fill": 0.5
		},
		{
			"name": "Lower Reservoir",
			"points": PackedVector2Array([
				Vector2(0.567009, 0.527886),
				Vector2(0.577780, 0.534677),
				Vector2(0.586016, 0.534677),
				Vector2(0.593619, 0.517699),
				Vector2(0.594252, 0.514303),
				Vector2(0.589184, 0.512605),
				Vector2(0.582215, 0.505814),
				Vector2(0.577780, 0.505814),
				Vector2(0.573978, 0.502418),
				Vector2(0.567009, 0.504116),
				Vector2(0.564475, 0.499022),
				Vector2(0.563841, 0.495626),
				Vector2(0.561941, 0.499022),
				Vector2(0.560673, 0.502418),
				Vector2(0.557506, 0.499022),
				Vector2(0.556872, 0.512605),
				Vector2(0.556872, 0.522792),
				Vector2(0.558773, 0.532979),
				Vector2(0.568910, 0.526188)
			]),
			"start_fill": 0.55,
			"full_fill": 0.95
		},
		{
			"name": "Outer Reservoir",
			"points": PackedVector2Array([
				Vector2(0.784954, 0.415826),
				Vector2(0.788121, 0.426013),
				Vector2(0.790656, 0.429409),
				Vector2(0.798892, 0.424316),
				Vector2(0.800159, 0.419222),
				Vector2(0.803960, 0.417524),
				Vector2(0.803960, 0.424316),
				Vector2(0.814731, 0.426013),
				Vector2(0.817265, 0.429409),
				Vector2(0.819166, 0.437899),
				Vector2(0.824868, 0.434503),
				Vector2(0.826135, 0.432805),
				Vector2(0.836272, 0.426013),
				Vector2(0.830570, 0.419222),
				Vector2(0.826135, 0.415826),
				Vector2(0.818532, 0.415826),
				Vector2(0.815364, 0.409035),
				Vector2(0.805861, 0.402243),
				Vector2(0.796991, 0.415826),
				Vector2(0.795091, 0.410733),
				Vector2(0.791289, 0.419222)
			]),
			"start_fill": 0.70,
			"full_fill": 0.90
		}
	]

	generator_layout_positions = {
		"atomic_friction": Vector2(0.511371, 0.422583),
		"molecular_agitation": Vector2(0.460384, 0.359855),
		"thermal_furnace": Vector2(0.574602, 0.378433),
		"thermal_compressor": Vector2(0.615829, 0.254067),
		"lava_mite_colony": Vector2(0.662417, 0.454621),
		"matter_furnace": Vector2(0.399357, 0.253207),
		"infernal_forge": Vector2(0.334125, 0.250783)
	}

	brazier_layout_positions = {
		"stability": Vector2(0.284469, 0.12257),
		"density": Vector2(0.225378, 0.263042),
		"integrity": Vector2(0.831101, 0.231573),
		"intensity": Vector2(0.688068, 0.179388),
		"resonance": Vector2(0.541076, 0.096425)
	}

	ash_pile_layout_positions = PackedVector2Array([
		Vector2(0.16, 0.49),
		Vector2(0.29, 0.44),
		Vector2(0.42, 0.52),
		Vector2(0.57, 0.46),
		Vector2(0.71, 0.52),
		Vector2(0.84, 0.47)
	])
