class_name CardSet extends Resource

@export var id: StringName
@export var display_name: String
@export var description: String = ""
@export var is_private: bool = false

## Room to grow: set symbol, release date, booster pack art defaults, etc.
@export var set_icon: Texture2D
