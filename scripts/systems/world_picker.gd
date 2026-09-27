class_name WorldPicker
extends RefCounted
## Camera rays pick contacts at any altitude and from any orbit angle.
static func hit_distance(camera: Camera3D, screen: Vector2, entity: SpaceEntity) -> float:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	if entity is Ship and is_instance_valid(entity.model):
		var inverse: Transform3D = entity.model.global_transform.affine_inverse()
		var local_origin: Vector3 = inverse * origin
		var local_direction: Vector3 = (inverse.basis * direction).normalized()
		var bounds := AABB(Vector3(-2.4, -1.2, -8.7), Vector3(4.8, 3.8, 17.0))
		if entity is SupportCraft:
			bounds = AABB(Vector3(-1.3, -0.8, -1.9), Vector3(2.6, 2.0, 4.2)) if entity.is_tug() else AABB(Vector3(-1, -0.9, -1.2), Vector3(2, 1.6, 2.5))
		var hit = bounds.intersects_ray(local_origin, local_direction)
		return origin.distance_to(entity.model.global_transform * hit) if hit != null else INF
	var center := entity.global_position
	var offset := origin - center
	var projection := offset.dot(direction)
	var discriminant := projection * projection - (offset.length_squared() - pow(maxf(3.0, entity.radius), 2))
	if discriminant < 0: return INF
	var near := -projection - sqrt(discriminant)
	var far := -projection + sqrt(discriminant)
	return maxf(0, near) if far >= 0 else INF
