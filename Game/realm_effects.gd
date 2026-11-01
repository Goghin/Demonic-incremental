class_name RealmEffects
extends RefCounted


const STABILITY_THRESHOLD_BONUS: float = 0.1

const DENSITY_THERMAL_MASS_BONUS: float = 0.05

const DENSITY_MATTER_PRODUCTION_BONUS: float = 0.05

const DENSITY_MATTER_DECAY_THRESHOLD_BONUS: float = 0.05

const INTENSITY_HEAT_PRODUCTION_BONUS: float = 0.1

const INTEGRITY_GENERATOR_COST_BONUS: float = 0.05

const INTEGRITY_ASHEN_CONTAMINATION_BONUS: float = 0.05

const ASSIGNED_FLAME_UPGRADE_ID: String = "realm_attunement"
const HEAT_PRODUCTION_UPGRADE_ID: String = "eternal_furnace"
const FLAME_DIMINISHING_RETURNS_EXPONENT: float = 0.35
const FLAME_SOFT_START: float = 10.0
const FLAME_SOFT_START_EXPONENT: float = 0.75


static func get_assigned_flame_scaling(flames: float) -> float:
	if flames <= 0.0:
		return 0.0
	return flames * pow(
		(1.0 + 1.0 / FLAME_SOFT_START) / (1.0 + flames / FLAME_SOFT_START),
		FLAME_SOFT_START_EXPONENT
	)


var heat_leak_threshold: float = 0.0
var matter_decay_threshold: float = 0.0

var thermal_mass_multiplier: float = 1.0
var matter_production_multiplier: float = 1.0

var heat_production_realm_multiplier: float = 1.0
var heat_production_upgrade_multiplier: float = 1.0
var heat_production_multiplier: float = 1.0

var generator_cost_multiplier: float = 1.0

var ashen_contamination_multiplier: float = 1.0


func rebuild(
	realm_configuration: RealmConfiguration,
	eternal_flame_state: EternalFlameState,
	eternal_flame_upgrade_manager: EternalFlameUpgradeManager,
	base_heat_leak_threshold: float,
	base_matter_decay_threshold: float
	) -> void:
	
	var stability = realm_configuration.stability
	var density = realm_configuration.density
	var integrity = realm_configuration.integrity
	var intensity = realm_configuration.intensity
	
	var assigned_flame_multiplier = (
		eternal_flame_upgrade_manager.get_effective_multiplier(
			ASSIGNED_FLAME_UPGRADE_ID,
			eternal_flame_state
		)
	)
	
	# ---------------------------------------------------------------
	# Integrity - Generator Cost
	# ---------------------------------------------------------------
	
	var integrity_cost_bonus = (
		INTEGRITY_GENERATOR_COST_BONUS
		* pow(integrity, FLAME_DIMINISHING_RETURNS_EXPONENT)
	)
	
	generator_cost_multiplier = 1.0 / (
		1.0
		+ integrity_cost_bonus
	)
	
	# ---------------------------------------------------------------
	# Stability - Heat Leak Threshold
	# ---------------------------------------------------------------
	
	var stability_bonus = (
		get_assigned_flame_scaling(stability)
		* STABILITY_THRESHOLD_BONUS
		* assigned_flame_multiplier
	)
	
	heat_leak_threshold = (
		base_heat_leak_threshold
		* (
			1.0
			+ stability_bonus

		)
	)
	
	# ---------------------------------------------------------------
	# Density - Thermal Mass
	# ---------------------------------------------------------------
	
	var thermal_mass_bonus = (
		get_assigned_flame_scaling(density)
		* DENSITY_THERMAL_MASS_BONUS
		* assigned_flame_multiplier
	)
	
	thermal_mass_multiplier = (
		1.0
		+ thermal_mass_bonus
	)
	
	# ---------------------------------------------------------------
	# Density - Matter Production
	# ---------------------------------------------------------------
	
	var matter_production_bonus = (
		get_assigned_flame_scaling(density)
		* DENSITY_MATTER_PRODUCTION_BONUS
		* assigned_flame_multiplier
	)
	
	matter_production_multiplier = (
		1.0
		+ matter_production_bonus
	)
	
	# ---------------------------------------------------------------
	# Density - Matter Decay Threshold
	# ---------------------------------------------------------------
	
	var matter_decay_threshold_bonus = (
		get_assigned_flame_scaling(density)
		* DENSITY_MATTER_DECAY_THRESHOLD_BONUS
		* assigned_flame_multiplier
	)
	
	matter_decay_threshold = (
		base_matter_decay_threshold
		* (
			1.0
			+ matter_decay_threshold_bonus

		)
	)
	
	# ---------------------------------------------------------------
	# Intensity - Heat Production
	# ---------------------------------------------------------------
	
	var heat_production_bonus = (
		get_assigned_flame_scaling(intensity)
		* INTENSITY_HEAT_PRODUCTION_BONUS
		* assigned_flame_multiplier
	)
	
	heat_production_realm_multiplier = (
		1.0
		+ heat_production_bonus
	)
	
	heat_production_upgrade_multiplier = (
		eternal_flame_upgrade_manager.get_effective_multiplier(
			HEAT_PRODUCTION_UPGRADE_ID,
			eternal_flame_state
		)
	)
	
	heat_production_multiplier = (
		heat_production_realm_multiplier
		* heat_production_upgrade_multiplier
	)
	
	# ---------------------------------------------------------------
	# Integrity - Ashen Contamination
	# ---------------------------------------------------------------
	
	var integrity_contamination_bonus = (
		INTEGRITY_ASHEN_CONTAMINATION_BONUS
		* get_assigned_flame_scaling(integrity)
		* assigned_flame_multiplier
	)
	
	ashen_contamination_multiplier = (
		1.0
		+ integrity_contamination_bonus
	)
