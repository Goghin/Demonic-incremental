class_name RealmEffects
extends RefCounted


const STABILITY_THRESHOLD_BONUS: float = 0.05
const UNASSIGNED_STABILITY_BONUS: float = 0.01

const DENSITY_THERMAL_MASS_BONUS: float = 0.05
const UNASSIGNED_DENSITY_THERMAL_MASS_BONUS: float = 0.01

const DENSITY_MATTER_PRODUCTION_BONUS: float = 0.05
const UNASSIGNED_DENSITY_MATTER_PRODUCTION_BONUS: float = 0.01

const DENSITY_MATTER_DECAY_THRESHOLD_BONUS: float = 0.05
const UNASSIGNED_DENSITY_MATTER_DECAY_THRESHOLD_BONUS: float = 0.01

const INTENSITY_HEAT_PRODUCTION_BONUS: float = 0.05
const UNASSIGNED_HEAT_PRODUCTION_BONUS: float = 0.01

const INTEGRITY_GENERATOR_COST_BONUS: float = 0.05
const UNASSIGNED_INTEGRITY_GENERATOR_COST_BONUS: float = 0.01

const INTEGRITY_ASHEN_CONTAMINATION_BONUS: float = 0.05
const UNASSIGNED_INTEGRITY_ASHEN_CONTAMINATION_BONUS: float = 0.01

const ASSIGNED_FLAME_UPGRADE_ID: String = "realm_attunement"
const UNASSIGNED_FLAME_UPGRADE_ID: String = "infernal_foundation"
const HEAT_PRODUCTION_UPGRADE_ID: String = "eternal_furnace"


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
	
	var unassigned_flames = (
		eternal_flame_state.get_unassigned_flames(
			realm_configuration
		)
	)
	
	var assigned_flame_multiplier = (
		eternal_flame_upgrade_manager.get_effective_multiplier(
			ASSIGNED_FLAME_UPGRADE_ID,
			eternal_flame_state
		)
	)
	
	var unassigned_flame_multiplier = (
		eternal_flame_upgrade_manager.get_effective_multiplier(
			UNASSIGNED_FLAME_UPGRADE_ID,
			eternal_flame_state
		)
	)
	
	# ---------------------------------------------------------------
	# Integrity - Generator Cost
	# ---------------------------------------------------------------
	
	var integrity_cost_bonus = (
		INTEGRITY_GENERATOR_COST_BONUS
		* pow(integrity, 0.35)
	)
	
	var unassigned_integrity_cost_bonus = (
		UNASSIGNED_INTEGRITY_GENERATOR_COST_BONUS
		* pow(unassigned_flames, 0.35)
	)
	
	generator_cost_multiplier = 1.0 / (
		1.0
		+ integrity_cost_bonus
		+ unassigned_integrity_cost_bonus
	)
	
	# ---------------------------------------------------------------
	# Stability - Heat Leak Threshold
	# ---------------------------------------------------------------
	
	var stability_bonus = (
		stability
		* STABILITY_THRESHOLD_BONUS
		* assigned_flame_multiplier
	)
	
	var unassigned_stability_bonus = (
		unassigned_flames
		* UNASSIGNED_STABILITY_BONUS
		* unassigned_flame_multiplier
	)
	
	heat_leak_threshold = (
		base_heat_leak_threshold
		* (
			1.0
			+ stability_bonus
			+ unassigned_stability_bonus
		)
	)
	
	# ---------------------------------------------------------------
	# Density - Thermal Mass
	# ---------------------------------------------------------------
	
	var thermal_mass_bonus = (
		density
		* DENSITY_THERMAL_MASS_BONUS
		* assigned_flame_multiplier
	)
	
	var unassigned_thermal_mass_bonus = (
		unassigned_flames
		* UNASSIGNED_DENSITY_THERMAL_MASS_BONUS
		* unassigned_flame_multiplier
	)
	
	thermal_mass_multiplier = (
		1.0
		+ thermal_mass_bonus
		+ unassigned_thermal_mass_bonus
	)
	
	# ---------------------------------------------------------------
	# Density - Matter Production
	# ---------------------------------------------------------------
	
	var matter_production_bonus = (
		density
		* DENSITY_MATTER_PRODUCTION_BONUS
		* assigned_flame_multiplier
	)
	
	var unassigned_matter_production_bonus = (
		unassigned_flames
		* UNASSIGNED_DENSITY_MATTER_PRODUCTION_BONUS
		* unassigned_flame_multiplier
	)
	
	matter_production_multiplier = (
		1.0
		+ matter_production_bonus
		+ unassigned_matter_production_bonus
	)
	
	# ---------------------------------------------------------------
	# Density - Matter Decay Threshold
	# ---------------------------------------------------------------
	
	var matter_decay_threshold_bonus = (
		density
		* DENSITY_MATTER_DECAY_THRESHOLD_BONUS
		* assigned_flame_multiplier
	)
	
	var unassigned_matter_decay_threshold_bonus = (
		unassigned_flames
		* UNASSIGNED_DENSITY_MATTER_DECAY_THRESHOLD_BONUS
		* unassigned_flame_multiplier
	)
	
	matter_decay_threshold = (
		base_matter_decay_threshold
		* (
			1.0
			+ matter_decay_threshold_bonus
			+ unassigned_matter_decay_threshold_bonus
		)
	)
	
	# ---------------------------------------------------------------
	# Intensity - Heat Production
	# ---------------------------------------------------------------
	
	var heat_production_bonus = (
		intensity
		* INTENSITY_HEAT_PRODUCTION_BONUS
		* assigned_flame_multiplier
	)
	
	var unassigned_heat_production_bonus = (
		unassigned_flames
		* UNASSIGNED_HEAT_PRODUCTION_BONUS
		* unassigned_flame_multiplier
	)
	
	heat_production_realm_multiplier = (
		1.0
		+ heat_production_bonus
		+ unassigned_heat_production_bonus
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
		* integrity
		* assigned_flame_multiplier
	)
	
	var unassigned_contamination_bonus = (
		UNASSIGNED_INTEGRITY_ASHEN_CONTAMINATION_BONUS
		* unassigned_flames
		* unassigned_flame_multiplier
	)
	
	ashen_contamination_multiplier = (
		1.0
		+ integrity_contamination_bonus
		+ unassigned_contamination_bonus
	)
