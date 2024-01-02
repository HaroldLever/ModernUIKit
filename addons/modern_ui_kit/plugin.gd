@tool
extends EditorPlugin


func _enter_tree():
	add_custom_type(
		"ModernScrollContainer", 
		"Container", 
		preload("res://addons/modern_ui_kit/scripts/modern_scroll_container.gd"), 
		preload("res://addons/modern_ui_kit/plugin_icon.svg")
	)


func _exit_tree():
	# Clean-up of the plugin goes here.
	pass
