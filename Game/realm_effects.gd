class_name RealmEffects
extends RefCounted


const STABILITY_THRESHOLD_BONUS: float = 0.05
const UNASSIGNED_STABILITY_BONUS: float = 0.01

const DENSITY_THERMAL_MASS_BONUS: float = 0.05
const UNASSIGNED_DENSITY_THERMAL_MASS_BONUS: float = 0.01

const DENSITY_MATTER_DECAY_THRESHOLD_BONUS: float = 0.05
const UNASSIGNED_DENSITY_MATTER_DECAY_THRESHOLD_BONUS: float = 0.01

const ASSIGNED_FLAME_UPGRADE_ID: String = "realm_attunement"
const UNASSIGNED_FLAME_UPGRADE_ID: String = "infernal_foundation"


var heat_leak_threshold: float = 0.0
var matter_decay_threshold: float = 0.0
var thermal_mass_multiplier: float = 1.0


func rebuild(
	realm_configuration: RealmConfiguration,
	eternal_flame_state: EternalFlameState,
	eternal_flame_upgrade_manager: EternalFlameUpgradeManager,
	base_heat_leak_threshold: float,
	base_matter_decay_threshold: float
	) -> void:
	
	var stability = realm_configuration.stability
	var density = realm_configuration.density
	
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
	
	# ----------------------------------------------------------------
	# Stability
	# ----------------------------------------------------------------
	
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
	
	var stability_multiplier = (
		1.0
		+ stability_bonus
		+ unassigned_stability_bonus
	)
	
	heat_leak_threshold = (
		base_heat_leak_threshold
		* stability_multiplier
	)
	
	# ----------------------------------------------------------------
	# Density - Thermal Mass
	# ----------------------------------------------------------------
	
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
	
	# ----------------------------------------------------------------
	# Density - Matter Decay Threshold
	# ----------------------------------------------------------------
	
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
	
	var matter_decay_threshold_multiplier = (
		1.0
		+ matter_decay_threshold_bonus
		+ unassigned_matter_decay_threshold_bonus
	)
	
	matter_decay_threshold = (
		base_matter_decay_threshold
		* matter_decay_threshold_multiplier
	)
