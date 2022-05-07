extends Node2D

enum {
	AI_HONEST = 0,
	AI_SMALL_BLUFF,
	AI_BLUFF,
}
const INIT_BALANCE = 400

const KEY_LOGIN_DATE = "LoginDate"
const KEY_BALANCE = "balance"
const KEY_USER_NAME = "user_name"

var ai_type = AI_HONEST		# AI タイプ
var saved_data = {}			# 自動保存データ辞書


const AutoSaveFileName	= "user://HoldemPoker_autosave.dat"		# 自動保存ファイル

func _ready():
	pass # Replace with function body.
#
func today_string():
	var d = OS.get_date()
	return "%04d/%02d/%02d" % [d["year"], d["month"], d["day"]]
#
func auto_load():
	var file = File.new()
	if !file.file_exists(AutoSaveFileName):
		saved_data = {}
	else:
		file.open(AutoSaveFileName, File.READ)
		saved_data = file.get_var()
		file.close()
	#
	if !saved_data.has(KEY_BALANCE): saved_data[KEY_BALANCE] = INIT_BALANCE
	if !saved_data.has(KEY_USER_NAME): saved_data[KEY_USER_NAME] = "Human"
	return saved_data
func auto_save():
	saved_data[KEY_LOGIN_DATE] = today_string()
	var file = File.new()
	file.open(AutoSaveFileName, File.WRITE)
	file.store_var(saved_data)
	file.close()
