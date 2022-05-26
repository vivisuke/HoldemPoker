extends Node2D

const LOGIN_BONUS = 100

onready var g = get_node("/root/Global")

func _ready():
	g.auto_load()
	if !g.saved_data.has(g.KEY_LOGIN_DATE) || g.saved_data[g.KEY_LOGIN_DATE] != g.today_string():
		g.saved_data[g.KEY_BALANCE] += LOGIN_BONUS
		g.auto_save()
	$BalanceLabel.text = String(g.saved_data[g.KEY_BALANCE])
	$UserNameEdit.text = g.saved_data[g.KEY_USER_NAME]
	pass # Replace with function body.


func to_MainScene():
	print("to_MainScene()")
	#g.saved_data[g.KEY_USER_NAME] = $UserNameEdit.text
	#g.auto_save()
	get_tree().change_scene("res://MainScene.tscn")

func _on_Button0_pressed():
	g.ai_type = g.AI_HONEST
	#get_tree().change_scene("res://MainScene.tscn")
	to_MainScene()
	pass # Replace with function body.
func _on_Button1_pressed():
	g.ai_type = g.AI_SMALL_BLUFF
	#get_tree().change_scene("res://MainScene.tscn")
	to_MainScene()
	pass # Replace with function body.
func _on_Button2_pressed():
	get_tree().change_scene("res://KuhnPokerScene.tscn")
	pass # Replace with function body.
func _on_Button3_pressed():
	get_tree().change_scene("res://3PKuhnPokerScene.tscn")
	pass # Replace with function body.


func _on_UserNameEdit_text_changed(new_text):
	g.saved_data[g.KEY_USER_NAME] = new_text
	g.auto_save()
	pass # Replace with function body.


func _on_UserNameEdit_text_entered(new_text):
	#print("new text = ", new_text)
	#g.saved_data[g.KEY_USER_NAME] = new_text
	#g.auto_save()
	pass # Replace with function body.


