extends CanvasLayer
##Autoload

signal hover_source_changed(source: Node)

@export var padding : float = 4.0
@export var tween_duration: float = 0.12

@onready var _sprite: NinePatchRect = $Indicator

var _current : Node = null
var _tween : Tween

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	layer = 100
	_sprite.visible = false
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE

func focus(source: CanvasItem, local_rect: Rect2, instant: bool = false) -> void:
	var source_changed := source != _current
	_current = source
	if source_changed:
		hover_source_changed.emit(_current)
	if not source.tree_exiting.is_connected(unfocus):
		source.tree_exiting.connect(unfocus.bind(source), CONNECT_ONE_SHOT)

	var xform := source.get_global_transform_with_canvas()
	#Grow in LOCAL space (not after transforming) so the padding rotates
	#and scales along with the card instead of always being screen-aligned.
	var expanded := local_rect.grow(padding)

	var target_pos := xform * expanded.position
	var target_size := expanded.size * xform.get_scale()
	var target_rot := xform.get_rotation()

	_sprite.visible = true
	_sprite.pivot_offset = Vector2.ZERO  #rotate around the same corner we're positioning

	if _tween:
		_tween.kill()

	if instant:
		#Used for continuous per-frame tracking (e.g. while dragging) --
		#tweening here would double up on the card's own drag smoothing
		#and make the indicator visibly lag behind.
		_sprite.global_position = target_pos
		_sprite.size = target_size
		_sprite.rotation = target_rot
	else:
		_tween = create_tween().set_parallel(true) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_sprite, "global_position", target_pos, tween_duration)
		_tween.tween_property(_sprite, "size", target_size, tween_duration)
		_tween.tween_property(_sprite, "rotation", target_rot, tween_duration)

## Identity-guarded so a stale mouse_exited (from moving straight from one
## hoverable onto another overlapping one) can't hide a highlight that a
## *newer* hover just claimed -- same pattern as ChoiceManager._pending.
func unfocus(source: Node) -> void:
	if source == _current:
		_current = null
		if _tween: _tween.kill()
		_sprite.visible = false
		hover_source_changed.emit(null)

##Method to force the hover to unfocus despite any current node being selected
##Used on scripts outside the ui nodes, e.g: CardInspector
func force_unfocus() -> void:
	if _current == null:
		return
	_current = null
	if _tween: _tween.kill()
	_sprite.visible = false
	hover_source_changed.emit(null)
## Convenience for plain Controls (buttons, panels) -- one line to opt in,
## no subclassing needed.
func register_hover(control: Control) -> void:
	control.mouse_entered.connect(_on_control_entered.bind(control))
	control.mouse_entered.connect(func(): SoundManager.play(&"hover", -2.0))
	control.tree_exiting.connect(unfocus.bind(control), CONNECT_ONE_SHOT)
	control.visibility_changed.connect(unfocus.bind(control))

func _on_control_entered(control: Control) -> void:
	if control is BaseButton and control.disabled:
		return
	focus(control, Rect2(Vector2.ZERO, control.size))
