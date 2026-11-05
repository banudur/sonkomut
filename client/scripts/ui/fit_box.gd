class_name FitBox
extends Container
## Tek çocuğunu ekrana sığdırır: içerik yüksekse kaydırmak yerine orantılı küçültür.
## Sığıyorsa çocuk tüm alanı kaplar, böylece esnek (EXPAND_FILL) öğeler boşluğu doldurur.


func _get_minimum_size() -> Vector2:
	return Vector2.ZERO


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		for child in get_children():
			var c := child as Control
			if c == null or not c.visible:
				continue
			var need := c.get_combined_minimum_size()
			var k := 1.0
			if need.y > 0.0 and need.y > size.y:
				k = size.y / need.y
			if need.x > 0.0 and need.x * k > size.x:
				k = size.x / need.x
			k = maxf(k, 0.4)
			c.scale = Vector2(k, k)
			c.position = Vector2.ZERO
			c.size = Vector2(size.x / k, maxf(size.y / k, need.y))
