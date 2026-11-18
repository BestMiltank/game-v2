extends RefCounted
## QA only: measure opaque contact between existing rendered part textures.
## Uses the final Sprite2D transforms; does not pose or connect any body part.
var images: Dictionary = {}

func opaque_at(art: Sprite2D, inverse: Transform2D, point: Vector2) -> bool:
	if not images.has(art.texture): images[art.texture] = art.texture.get_image()
	var im: Image = images[art.texture]
	var uv := Vector2i((inverse * point - art.get_rect().position).floor())
	return uv.x >= 0 and uv.y >= 0 and uv.x < im.get_width() and uv.y < im.get_height() and im.get_pixelv(uv).a >= 0.5

func overlap(a: Sprite2D, b: Sprite2D) -> float:
	var bounds: Rect2 = (a.transform * a.get_rect()).intersection(b.transform * b.get_rect())
	if not bounds.has_area(): return 0.0
	var ia := a.transform.affine_inverse()
	var ib := b.transform.affine_inverse()
	var count := 0
	# Half-source-pixel grid, aligned globally so mirrored poses are equivalent.
	for y in range(floori(bounds.position.y*2),ceili(bounds.end.y*2)):
		for x in range(floori(bounds.position.x*2),ceili(bounds.end.x*2)):
			var p := Vector2(x+0.5,y+0.5)*0.5
			if opaque_at(a,ia,p) and opaque_at(b,ib,p): count += 1
	return count*0.25

func measure(rig: Node2D) -> Dictionary:
	var result := {}
	for side in ["L","R"]:
		var leg: Sprite2D = rig.sprites["noumenon/body/"+side+"_leg"]
		result[side+"_hip"] = overlap(rig.sprites["noumenon/body"],leg)
		result[side+"_ankle"] = overlap(leg,rig.sprites["noumenon/"+side+"foot"])
	return result
