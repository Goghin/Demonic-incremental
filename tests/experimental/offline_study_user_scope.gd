extends RefCounted

# Native SaveManager uses user://savegame.json. Refuse unscoped direct runs
# before constructing GameState or invoking native save/log operations.
static func rejection() -> String:
	if OS.get_name() != "Linux":
		return "Study user-data isolation is only validated on Linux"
	var expected: String = OS.get_environment("TM_STUDY_USER_ROOT").simplify_path()
	if expected.is_empty() or not expected.is_absolute_path():
		return "Use run_offline_integration_study.py with a private user-data directory"
	var actual: String = OS.get_user_data_dir().simplify_path()
	if not actual.begins_with(expected + "/"):
		return "Native user-data directory is outside the study sandbox"
	return ""
