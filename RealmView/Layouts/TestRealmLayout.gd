
extends RealmLayout


func _init() -> void:
	island_texture = preload("res://RealmView/Island_2 (1).png")
	#island_texture = preload( "res://RealmView/2islands.png")
	lava_flow_definitions = [{
			"points": PackedVector2Array([
				Vector2(0.577780, 0.546562),
				Vector2(0.593619, 0.575426)
			]),
			"widths": PackedFloat32Array([
				1.8,
				2.8
			]),
			"speed": 35.0,
			"thickness": 3.0,
			"flow_z": 6,
			"fall_width": 3.0,
			"fall_length": 85.0,
			"fall_speed": 95.0,
			"fall_z": 7,
			"start_fill": .22,
			"stop_fill": 0.12,
			},{
			"points": PackedVector2Array([
			Vector2(0.516184, 0.424316),
			Vector2(0.506681, 0.444690),
			Vector2(0.507948, 0.475252),
			Vector2(0.488941, 0.529584),
			Vector2(0.480071, 0.589009)
		]),
			"widths": PackedFloat32Array([2.0, 3.0, 5.0, 8.0, 11.0]),
			"speed": 15.0,
			"thickness": 1.0,
			"flow_z": 6,
			"start_fill": 0.30,
			"stop_fill": 0.20,
			"fall_width": 10.5,
			"fall_length": 160.0,
			"fall_speed": 80.0,
			"fall_z": 7
		},{
	"points": PackedVector2Array([
		Vector2(0.543567, 0.361494),
		Vector2(0.553071, 0.351307),
		Vector2(0.557506, 0.330933),
		Vector2(0.577780, 0.315652),
		Vector2(0.594252, 0.290184),
		Vector2(0.623396, 0.259622),
		Vector2(0.641136, 0.247737),
		Vector2(0.663310, 0.229060)
	]),
	"widths": PackedFloat32Array([
		3.6,
		3.2,
		3.0,
		2.8,
		2.5,
		2.2,
		1.8,
		1.3
	]),
	"speed": 20.0,
	"thickness": 1.0,
	"flow_z": 6,
	"start_fill": 0.40,
	"stop_fill": 0.30,
	"fall_width": 3.5,
	"fall_length": 320.0,
	"fall_speed": 120.0,
	"fall_z": 4
},{
	"points": PackedVector2Array([
		Vector2(0.554338, 0.431107),
		Vector2(0.578413, 0.451482),
		Vector2(0.584749, 0.470158),
		Vector2(0.612625, 0.505814),
		Vector2(0.646838, 0.532979),
		Vector2(0.688019, 0.573728)
	]),
	"widths": PackedFloat32Array([
		2.0,
		2.5,
		3.0,
		6.0,
		7.5,
		8.5
	]),
	"speed": 25.0,
	"thickness": 1.0,
	"flow_z": 6,
	"start_fill": 0.48,
	"stop_fill": 0.42,
	"fall_width": 8.5,
	"fall_length": 220.0,
	"fall_speed": 120.0,
	"fall_z": 7
},{
	"points": PackedVector2Array([
		Vector2(0.460571, 0.376775),
		Vector2(0.444732, 0.359796),
		Vector2(0.415588, 0.324141),
		Vector2(0.402917, 0.313954),
		Vector2(0.388345, 0.303767),
		Vector2(0.376941, 0.296975),
		Vector2(0.361102, 0.269809),
		Vector2(0.352866, 0.235852),
		Vector2(0.338928, 0.220571)
	]),
	"widths": PackedFloat32Array([
		4.7,
		4.3,
		3.9,
		3.5,
		3.0,
		2.2,
		2.0,
		1.5,
		1.2
	]),
	"speed": 20.0,
	"thickness": 1.0,
	"flow_z": 6,
	"start_fill": 0.55,
	"stop_fill": 0.50,
	"fall_width": 6.5,
	"fall_length": 320.0,
	"fall_speed": 120.0,
	"fall_z": 4
},{
	"points": PackedVector2Array([
		Vector2(0.625297, 0.339422),
		Vector2(0.651906, 0.332630),
		Vector2(0.688019, 0.310558),
		Vector2(0.703225, 0.305464),
		Vector2(0.722231, 0.290184),
		Vector2(0.739337, 0.274903)
	]),
	"widths": PackedFloat32Array([
		2.0,
		2.5,
		3.5,
		3.0,
		3.5,
		4.0
	]),
	"speed": 25.0,
	"thickness": 1.0,
	"flow_z": 6,
	"start_fill": 0.60,
	"stop_fill": 0.55,
	"fall_width": 4.5,
	"fall_length": 220.0,
	"fall_speed": 120.0,
	"fall_z": 4
},{
	"points": PackedVector2Array([
		Vector2(0.441564, 0.388660),
		Vector2(0.411153, 0.380171),
		Vector2(0.376308, 0.392056),
		Vector2(0.376308, 0.424316),
		Vector2(0.341462, 0.441294),
		Vector2(0.311685, 0.441294),
		Vector2(0.279373, 0.454877),
		Vector2(0.233757, 0.470158),
		Vector2(0.207147, 0.478648),
		Vector2(0.184339, 0.485439)
	]),
	"widths": PackedFloat32Array([
		5.0,
		4.5,
		4.0,
		3.5,
		3.0,
		2.5,
		2.0,
		4.0,
		5.0,
		7.0
	]),
	"speed": 35.0,
	"thickness": 1.0,
	"flow_z": 6,
	"start_fill": 0.85,
	"stop_fill": 0.78,
	"fall_width": 6.5,
	"fall_length": 220.0,
	"fall_speed": 220.0,
	"fall_z": 7
},{
	"points": PackedVector2Array([
		Vector2(0.731735, 0.388660),
		Vector2(0.733002, 0.422618),
		Vector2(0.723498, 0.449784),
		Vector2(0.711461, 0.468460),
		Vector2(0.738070, 0.480345),
		Vector2(0.732368, 0.502418),
		Vector2(0.774817, 0.522792)
	]),
	"widths": PackedFloat32Array([
		2.0,
		2.5,
		3.0,
		3.5,
		4.0,
		5.5,
		8.0
	]),
	"speed": 25.0,
	"thickness": 1.0,
	"flow_z": 6,
	"start_fill": 0.70,
	"stop_fill": 0.65,
	"fall_width": 6.5,
	"fall_length": 220.0,
	"fall_speed": 220.0,
	"fall_z": 7
},{
	"points": PackedVector2Array([
		Vector2(0.454236, 0.419222),
		Vector2(0.438397, 0.427711),
		Vector2(0.419390, 0.448086),
		Vector2(0.395314, 0.436201),
		Vector2(0.391513, 0.415826),
		Vector2(0.377575, 0.422618)
	]),
	"widths": PackedFloat32Array([
		2.5,
		2.8,
		2.0,
		1.4,
		2.0,
		2.2
	]),
	"speed": 25.0,
	"thickness": 1.0,
	"flow_z": 6,
	"start_fill": 0.9,
	"stop_fill": 0.85,
	"fall_width": 0,
	"fall_length": 0.0,
	"fall_speed": 0.0,
	"fall_z": 0
},{
	"points": PackedVector2Array([
		Vector2(0.468174, 0.436201),
		Vector2(0.447900, 0.473554),
		Vector2(0.472609, 0.510907),
		Vector2(0.464372, 0.526188),
		Vector2(0.454869, 0.595801)
	]),
	"widths": PackedFloat32Array([
		2.0,
		3.0,
		4.0,
		5.0,
		6.0
	]),
	"speed": 25.0,
	"thickness": 1.0,
	"flow_z": 6,
	"start_fill": 0.95,
	"stop_fill": 0.90,
	"fall_width": 6.5,
	"fall_length": 120.0,
	"fall_speed": 120.0,
	"fall_z": 7
},{
	"points": PackedVector2Array([
		Vector2(0.591084, 0.397150),
		Vector2(0.608191, 0.392056),
		Vector2(0.618961, 0.397150),
		Vector2(0.629098, 0.388660),
		Vector2(0.648738, 0.388660),
		Vector2(0.644937, 0.431107),
		Vector2(0.676615, 0.441294),
		Vector2(0.695622, 0.459971),
		Vector2(0.709560, 0.468460),
		Vector2(0.736803, 0.475252),
		Vector2(0.734269, 0.499022),
		Vector2(0.778618, 0.510907)
	]),
	"widths": PackedFloat32Array([
		2,
		2.2,
		2.0,
		2.4,
		2.0,
		2.5,
		3.0,
		4.0,
		5.0,
		6.0,
		7.0,
		9.0
	]),
	"speed": 25.0,
	"thickness": 1.0,
	"flow_z": 6,
	"start_fill": 0.75,
	"stop_fill": 0.70,
	"fall_width": 8.5,
	"fall_length": 220.0,
	"fall_speed": 180.0,
	"fall_z": 7
},{
	"points": PackedVector2Array([
		Vector2(0.421924, 0.349609),
		Vector2(0.385178, 0.339422),
		Vector2(0.373773, 0.366588),
		Vector2(0.330691, 0.358099),
		Vector2(0.295212, 0.356401),
		Vector2(0.257832, 0.353005),
		Vector2(0.255931, 0.353005),
		Vector2(0.209682, 0.346213),
		Vector2(0.208414, 0.346213),
		Vector2(0.145692, 0.337724),
		Vector2(0.124151, 0.347911)
	]),
	"widths": PackedFloat32Array([
		4.5,
		4,
		3.5,
		3.0,
		2.5,
		2.0,
		0.0,
		0.0,
		3.0,
		4.0,
		5.0
	]),
	"speed": 25.0,
	"thickness": 1.0,
	"flow_z": 5,
	"start_fill": 0.95,
	"stop_fill": 0.90,
	"fall_width": 6.5,
	"fall_length": 220.0,
	"fall_speed": 220.0,
	"fall_z": 4
},{
	"points": PackedVector2Array([
		Vector2(0.436496, 0.254528),
		Vector2(0.430794, 0.225664),
		Vector2(0.449167, 0.217175),
		Vector2(0.451068, 0.205290)
	]),
	"widths": PackedFloat32Array([
		2.0,
		2.0,
		2.7,
		3.0
	]),
	"speed": 25.0,
	"thickness": 1.0,
	"flow_z": 6,
	"start_fill": 0.95,
	"stop_fill": 0.90,
	"fall_width": 5.0,
	"fall_length": 180.0,
	"fall_speed": 220.0,
	"fall_z": 4
},{
	"points": PackedVector2Array([
		Vector2(0.311051, 0.492231),
		Vector2(0.323089, 0.507511),
		Vector2(0.308517, 0.519396),
		Vector2(0.297746, 0.524490),
		Vector2(0.283808, 0.544865)
	]),
	"widths": PackedFloat32Array([
		3.0,
		3.5,
		4.0,
		4.5,
		6.0
	]),
	"speed": 25.0,
	"thickness": 1.0,
	"flow_z": 6,
	"start_fill": 0.95,
	"stop_fill": 0.90,
	"fall_width": 6.5,
	"fall_length": 220.0,
	"fall_speed": 220.0,
	"fall_z": 7
},
	
	]

	main_lake_edge_points = PackedVector2Array([
	Vector2(0.457487, 0.328162),
	Vector2(0.473436, 0.322276),
	Vector2(0.489935, 0.339934),
	Vector2(0.505334, 0.328162),
	Vector2(0.512484, 0.326690),
	Vector2(0.517434, 0.345820),
	Vector2(0.533383, 0.336991),
	Vector2(0.553732, 0.320804),
	Vector2(0.568031, 0.307561),
	Vector2(0.575181, 0.311975),
	Vector2(0.565831, 0.323747),
	Vector2(0.573531, 0.332576),
	Vector2(0.568581, 0.348763),
	Vector2(0.568031, 0.364950),
	Vector2(0.577931, 0.366421),
	Vector2(0.587280, 0.391437),
	Vector2(0.597730, 0.385551),
	Vector2(0.605429, 0.397323),
	Vector2(0.604329, 0.410567),
	Vector2(0.597180, 0.420868),
	Vector2(0.597730, 0.431168),
	Vector2(0.608729, 0.434111),
	Vector2(0.586180, 0.457656),
	Vector2(0.588380, 0.476785),
	Vector2(0.570781, 0.456184),
	Vector2(0.557582, 0.463542),
	Vector2(0.548782, 0.469428),
	Vector2(0.540533, 0.457656),
	Vector2(0.524033, 0.457656),
	Vector2(0.517984, 0.453241),
	Vector2(0.510284, 0.475314),
	Vector2(0.498185, 0.475314),
	Vector2(0.494885, 0.469428),
	Vector2(0.500935, 0.457656),
	Vector2(0.488835, 0.450298),
	Vector2(0.474536, 0.450298),
	Vector2(0.467936, 0.453241),
	Vector2(0.462986, 0.432640),
	Vector2(0.442088, 0.429697),
	Vector2(0.443737, 0.410567),
	Vector2(0.422838, 0.400266),
	Vector2(0.415689, 0.389966),
	Vector2(0.409089, 0.372307),
	Vector2(0.413489, 0.354649),
	Vector2(0.423938, 0.338462),
])

	small_lake_definitions = [
		{
			"name": "Right Reservoir",
			"points": PackedVector2Array([
	Vector2(0.717074, 0.379665),
	Vector2(0.723673, 0.364950),
	Vector2(0.741823, 0.367893),
	Vector2(0.769321, 0.369364),
	Vector2(0.781421, 0.375250),
	Vector2(0.777021, 0.384080),
	Vector2(0.756672, 0.397323),
	Vector2(0.736323, 0.394380),
	Vector2(0.733023, 0.401738),
	Vector2(0.722024, 0.389966),
	Vector2(0.714324, 0.378193),
]),
			"start_fill": 0.15,
			"full_fill": 0.5
		},
		
		{
			"name": "Upper Reservoir",
			"points": PackedVector2Array([				
	Vector2(0.444732, 0.246039),
	Vector2(0.449801, 0.257924),
	Vector2(0.437763, 0.271507),
	Vector2(0.432694, 0.273205),
	Vector2(0.421290, 0.266413),
	Vector2(0.414955, 0.273205),
	Vector2(0.402284, 0.266413),
	Vector2(0.394047, 0.259622),
	Vector2(0.403551, 0.254528),
	Vector2(0.437763, 0.251133),
]),
			"start_fill": 0.70,
			"full_fill": 0.90
		},
		{
			"name": "Left Reservoir",
			"points": PackedVector2Array([
	Vector2(0.347164, 0.459971),
	Vector2(0.340828, 0.451482),
	Vector2(0.331958, 0.448086),
	Vector2(0.326257, 0.449784),
	Vector2(0.311051, 0.451482),
	Vector2(0.306616, 0.451482),
	Vector2(0.295212, 0.456575),
	Vector2(0.301548, 0.466762),
	Vector2(0.311685, 0.476950),
	Vector2(0.330691, 0.476950),
	Vector2(0.342729, 0.466762),
	
	
]),
			"start_fill": 0.55,
			"full_fill": 0.69
		},
	]



	generator_layout_positions = {
		"atomic_friction": Vector2(0.477792, 0.262983),
		"molecular_agitation": Vector2(0.422371, 0.519455),
		"thermal_furnace": Vector2(0.542924, 0.515961),
		"thermal_compressor": Vector2(0.622798, 0.269348),
		"lava_mite_colony": Vector2(0.682057, 0.468204),
		"matter_furnace": Vector2(0.539374, 0.071535),
		"infernal_forge": Vector2(0.232122, 0.306813)

	}

	brazier_layout_positions = {
		"stability": Vector2(0.284469, 0.12257),
		"density": Vector2(0.182929, 0.251157),
		"integrity": Vector2(0.831101, 0.231573),
		"intensity": Vector2(0.688068, 0.179388),
		"resonance": Vector2(0.359878, 0.14057)
	}

	ash_pile_layout_positions = PackedVector2Array([
		Vector2(0.22, 0.48),
		Vector2(0.32, 0.44),
		Vector2(0.43, 0.51),
		Vector2(0.57, 0.47),
		Vector2(0.69, 0.51),
		Vector2(0.77, 0.49)
	])
