extends RealmLayout


func _init() -> void:
	island_texture = preload("res://RealmView/infernal_island.png")
	main_lake_edge_points = PackedVector2Array([
		Vector2(0.457729, 0.338517),
		Vector2(0.502262, 0.341350),
		Vector2(0.516200, 0.352719),
		Vector2(0.531956, 0.354343),
		Vector2(0.536804, 0.346222),
		Vector2(0.554377, 0.339726),
		Vector2(0.559097, 0.342558),
		Vector2(0.570204, 0.333494),
		Vector2(0.581788, 0.348300),
		Vector2(0.593147, 0.383390),
		Vector2(0.596797, 0.386827),
		Vector2(0.602857, 0.391699),
		Vector2(0.601123, 0.417271),
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
		Vector2(0.441649, 0.350491)
	])
	small_lake_definitions = [
		{
			"name": "Upper Reservoir",
			"points": PackedVector2Array([
				Vector2(0.595519, 0.231714),
				Vector2(0.610830, 0.220300),
				Vector2(0.624623, 0.226832),
				Vector2(0.641441, 0.241134),
				Vector2(0.622604, 0.244235),
				Vector2(0.604678, 0.241803)
			]),
			"start_fill": 0.150000,
			"full_fill": 0.500000
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
			"start_fill": 0.550000,
			"full_fill": 0.950000
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
			"start_fill": 0.700000,
			"full_fill": 0.900000
		}
	]
	lava_flow_definitions = [
		{
			"points": PackedVector2Array([
				Vector2(0.671295, 0.658396)
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
			"fall_length": 124.062514,
			"fall_speed": 150.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.387498, 0.625537)
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
				Vector2(0.452891, 0.413845),
				Vector2(0.415473, 0.441856),
				Vector2(0.430331, 0.486083),
				Vector2(0.410521, 0.536208),
				Vector2(0.420426, 0.595177)
			]),
			"widths": PackedFloat32Array([
				2.000000,
				3.000000,
				3.000000,
				7.000000,
				8.000000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.400000,
			"stop_fill": 0.360000,
			"fall_width": 5.431238,
			"fall_length": 220.000000,
			"fall_speed": 220.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.575049, 0.443330),
				Vector2(0.623472, 0.474289),
				Vector2(0.622922, 0.506723),
				Vector2(0.638329, 0.531785),
				Vector2(0.633927, 0.584858)
			]),
			"widths": PackedFloat32Array([
				3.000000,
				4.000000,
				5.000000,
				6.000000,
				8.000000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.600000,
			"stop_fill": 0.550000,
			"fall_width": 5.500000,
			"fall_length": 165.000000,
			"fall_speed": 120.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.581658, 0.560398),
				Vector2(0.574305, 0.582914)
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
				Vector2(0.573254, 0.512552),
				Vector2(0.574305, 0.542104),
				Vector2(0.596365, 0.578692)
			]),
			"widths": PackedFloat32Array([
				4.000000,
				6.000000,
				9.000000
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
				Vector2(0.478710, 0.433747),
				Vector2(0.456124, 0.483000),
				Vector2(0.472407, 0.523810),
				Vector2(0.454548, 0.551955),
				Vector2(0.461376, 0.574471)
			]),
			"widths": PackedFloat32Array([
				4.000000,
				5.000000,
				6.000000,
				7.000000,
				9.000000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.550000,
			"stop_fill": 0.500000,
			"fall_width": 5.000000,
			"fall_length": 140.920270,
			"fall_speed": 125.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.825438, 0.425477),
				Vector2(0.834257, 0.461145)
			]),
			"widths": PackedFloat32Array([
				5.000000,
				4.000000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.650000,
			"stop_fill": 0.600000,
			"fall_width": 3.505505,
			"fall_length": 110.000000,
			"fall_speed": 95.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.702159, 0.469866),
				Vector2(0.691704, 0.511145),
				Vector2(0.698539, 0.576184)
			]),
			"widths": PackedFloat32Array([
				4.000000,
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
				Vector2(0.583847, 0.426827),
				Vector2(0.645213, 0.432340),
				Vector2(0.698264, 0.460485),
				Vector2(0.734506, 0.513960),
				Vector2(0.782829, 0.515367)
			]),
			"widths": PackedFloat32Array([
				2.000000,
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
			"fall_width": 4.964109,
			"fall_length": 119.642123,
			"fall_speed": 125.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.475417, 0.396223),
				Vector2(0.413053, 0.393308),
				Vector2(0.374754, 0.405000),
				Vector2(0.343133, 0.393892),
				Vector2(0.321550, 0.417274),
				Vector2(0.278910, 0.411480),
				Vector2(0.269104, 0.494929)
			]),
			"widths": PackedFloat32Array([
				2.000000,
				3.000000,
				3.000000,
				4.500000,
				4.000000,
				5.000000,
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
				Vector2(0.556340, 0.356350),
				Vector2(0.584147, 0.366326),
				Vector2(0.608615, 0.325390),
				Vector2(0.624805, 0.326785),
				Vector2(0.657038, 0.322442),
				Vector2(0.679599, 0.297380),
				Vector2(0.718117, 0.279689),
				Vector2(0.740678, 0.273792)
			]),
			"widths": PackedFloat32Array([
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
			"fall_width": 6.000000,
			"fall_length": 211.768743,
			"fall_speed": 100.000000,
			"fall_z": 4
		},
		{
			"points": PackedVector2Array([
				Vector2(0.428378, 0.382611),
				Vector2(0.377550, 0.410205),
				Vector2(0.345361, 0.395253),
				Vector2(0.322371, 0.417725),
				Vector2(0.280957, 0.407808),
				Vector2(0.252277, 0.415279),
				Vector2(0.228688, 0.442992),
				Vector2(0.184141, 0.484272)
			]),
			"widths": PackedFloat32Array([
				2.000000,
				2.135233,
				2.441303,
				2.739589,
				3.000000,
				3.000000,
				3.000000,
				4.000000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.920000,
			"stop_fill": 0.900000,
			"fall_width": 4.500000,
			"fall_length": 105.522323,
			"fall_speed": 140.000000,
			"fall_z": 7
		},
		{
			"points": PackedVector2Array([
				Vector2(0.418123, 0.353005),
				Vector2(0.387712, 0.336026),
				Vector2(0.371239, 0.347911),
				Vector2(0.342016, 0.308542),
				Vector2(0.275572, 0.317350),
				Vector2(0.257199, 0.313954),
				Vector2(0.209682, 0.330933),
				Vector2(0.127319, 0.346213)
			]),
			"widths": PackedFloat32Array([
				2.000000,
				2.500000,
				3.500000,
				4.000000,
				2.600000,
				0.000000,
				0.000000,
				4.500000
			]),
			"speed": 25.000000,
			"thickness": 1.000000,
			"flow_z": 6,
			"start_fill": 0.990000,
			"stop_fill": 0.950000,
			"fall_width": 5.944034,
			"fall_length": 160.000000,
			"fall_speed": 120.000000,
			"fall_z": 4
		}
	]
	generator_layout_positions = {
		"atomic_friction": Vector2(0.518855, 0.531778),
		"molecular_agitation": Vector2(0.382219, 0.464592),
		"thermal_furnace": Vector2(0.720123, 0.345006),
		"thermal_compressor": Vector2(0.615829, 0.254067),
		"lava_mite_colony": Vector2(0.452036, 0.247374),
		"matter_furnace": Vector2(0.540720, 0.057103),
		"infernal_forge": Vector2(0.310010, 0.290895)
	}
	brazier_layout_positions = {
		"stability": Vector2(0.283637, 0.122570),
		"density": Vector2(0.185464, 0.247443),
		"integrity": Vector2(0.831101, 0.227116),
		"intensity": Vector2(0.686405, 0.183845),
		"resonance": Vector2(0.361462, 0.134309)
	}
	ash_pile_layout_positions = PackedVector2Array([
		Vector2(0.579100, 0.276068),
		Vector2(0.388123, 0.292922),
		Vector2(0.420000, 0.520000),
		Vector2(0.570000, 0.460000),
		Vector2(0.710000, 0.520000),
		Vector2(0.784286, 0.314008)
	])

	matter_pile_layout_positions = PackedVector2Array([
		Vector2(0.240000, 0.550000),
		Vector2(0.490000, 0.600000),
		Vector2(0.770000, 0.550000)
	])
