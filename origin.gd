extends Node

## player skin colour(corresponds to the player texture's modulation)
var player_color: Color = Color.WHITE

func _ready() -> void:
	main_menu()

func reset_level() -> void:
	$Ingame/CrateSpawnDelay.stop()
	$Ingame/DeathDelay.stop()
	$Ingame/NextRoundDelay.stop()
	for enemy: Node in $Ingame/Enemies.get_children():
		enemy.queue_free()
	for bullet: Node in $Ingame/Bullets.get_children():
		bullet.queue_free()
	for physics_shape: Node in $Ingame/Map/PhysicsWalls.get_children():
		physics_shape.queue_free()
	for crate: Node in $Ingame/Crates.get_children():
		crate.queue_free()
	for layer: Node in $Ingame/Map.get_children():
		if not layer is TileMapLayer: continue
		layer.clear()
	$Ingame/Player.visible = false
	$Ingame/Player.process_mode = Node.PROCESS_MODE_DISABLED

func play() -> void:
	$MainMenu.activate(false)
	$Ingame/ScoresLayer.visible = true
	$Ingame/Camera.enabled = true
	$MenusBackground.visible = false
	$Ingame.process_mode = Node.PROCESS_MODE_INHERIT
	$Ingame.visible = true
	$Ingame.modified_ready()

func main_menu() -> void:
	reset_level()
	$MainMenu.activate(true)
	$Ingame.process_mode = Node.PROCESS_MODE_DISABLED
	$Ingame/Camera.enabled = false
	$Ingame/ScoresLayer.visible = false
	$MenusBackground.visible = true
	$Ingame.visible = false
