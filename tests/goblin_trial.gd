extends SceneTree

const Trial = preload("res://scenes/goblin_trial.tscn")
var yard
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.pressed=pressed
	root.push_input(event)

func tap(code: Key) -> void:
	key(code,true)
	key(code,false)

func run() -> void:
	yard=Trial.instantiate()
	root.add_child(yard)
	yard.set_process(false)
	var enemy=yard.raider
	var folder := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--demo-output="): folder=arg.trim_prefix("--demo-output=")
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder)
		yard.get_node("HUD").hide()
		yard.get_node("Ground").position.y+=120
	for miss in [Vector2(-90,0),Vector2(100,40),Vector2(175,0)]:
		enemy.reset_at(miss)
		tap(KEY_J)
		yard.advance(.8)
		check(enemy.hp==300,"miss when behind, outside lane or out of reach")
	tap(KEY_R)
	enemy.reset_at(Vector2(130,0))
	tap(KEY_J)
	yard.advance(.2)
	tap(KEY_J)
	yard.advance(.18)
	check(enemy.hp==246,"first smash reaches the outside edge")
	yard.advance(.38)
	check(enemy.hp==246,"pommel can miss after the long head connects")
	for facing in [1,-1]:
		tap(KEY_R)
		if facing<0:
			key(KEY_A,true)
			yard.advance(.01)
			key(KEY_A,false)
			yard.advance(.01)
			enemy.reset_at(yard.actor.position+Vector2(-100,0))
		var health := [300]
		var hold_sent := false
		for frame in range(108):
			if frame in [10,16,27]: tap(KEY_J)
			if yard.actor.attacks.index==2 and yard.actor.attacks.time>=.22 and not hold_sent:
				key(KEY_J,true)
				hold_sent=true
			yard.advance(1.0/30)
			if yard.actor.attacks.index==3 and yard.actor.attacks.time<yard.actor.rig.hammer_data.attacks[3].impact_at:
				check(enemy.hp==130,"airborne rotation cannot damage the target before ground contact")
			if health.back()!=enemy.hp: health.append(enemy.hp)
			if facing==1 and not folder.is_empty():
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_jpg(folder.path_join("%03d.jpg"%frame),.96)
		key(KEY_J,false)
		check(health==[300,246,206,130,0],"one contact per strike on both facings: "+str(health))
		check(enemy.animation==&"death","fourth strike defeats goblin")
		tap(KEY_ESCAPE)
		var at: float=enemy.elapsed
		yard.advance(2)
		check(enemy.elapsed==at,"pause freezes death and respawn")
		tap(KEY_ESCAPE)
		yard.advance(2)
		check(enemy.hp==300 and enemy.position==yard.SPAWN,"target respawns ready for another chain")
	print("GOBLIN TESTS: ",failures," failures")
	quit(1 if failures else 0)
