class_name ThermalCompressorUpgradeLayout
extends GeneratorUpgradeLayout


func _init() -> void:
	# Core compression progression
	add_node("thermal_compressor_optimization", 1, 0)

	# Specialization choice: prioritize Matter output or reduce Heat draw.
	add_node("high_pressure_compression", 0, 1)
	add_node("thermal_recovery", 2, 1)

	# General efficiency upgrade remains available after the specialization.
	add_node("thermal_compressor_efficiency", 1, 2)

	add_connection(
		"thermal_compressor_optimization",
		"high_pressure_compression"
	)

	add_connection(
		"thermal_compressor_optimization",
		"thermal_recovery"
	)

	add_connection(
		"high_pressure_compression",
		"thermal_compressor_efficiency"
	)

	add_connection(
		"thermal_recovery",
		"thermal_compressor_efficiency"
	)
