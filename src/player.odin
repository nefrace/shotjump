package main

import "core:math/linalg"
import "core:math/rand"
import rl "raylib"
import "core:math"

Position :: [3]f32

MAX_AMMO : i8 : 7

Player :: struct {
	using position: Position,
	velocity:       Vec3,
	size:           Vec3,
	shoot_point:	Vec3,
	health: 		f32,
	is_dead:		bool,
	invuln_time:	f32,
	direction:      f32,
	rotation:       f32,
	flip:           bool,
	rolling: 		bool,
	roll_angle: 	f32,
	is_on_floor:    bool,
	recoil_vec:     Vec2,
	ammo:			i8,
	reload_time:	f32,
	kills: 			i32,
}

player_update :: proc(player: ^Player, delta: f32) {
	player.velocity += GRAVITY * delta


	if !player.is_dead {
		if player.health <= 0 {
			player.is_dead = true
			player.velocity = {rand.float32_range(-5, 5), rand.float32_range(5,10), -10 if rand.float32() < 0.5 else 10}
		}
		mouse_pos := rl.GetMousePosition()
		player_pos := rl.GetWorldToScreen(player.position, camera)
		ray := rl.GetMouseRay(mouse_pos, camera)

		if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) && !player.rolling {
			if player.ammo > 0 && player.reload_time <= 0 {
				player.ammo -= 1
				bullet_spawn(player.shoot_point, rl.Vector3RotateByAxisAngle({1, 0, 0}, {0, 0, 1}, player.direction) * 25)
				boom_spawn(player.shoot_point, 0.5)
				player.velocity.xy = player.recoil_vec
			} else if player.reload_time <= 0 {
				player.reload_time = 1.2
			}
		}
		if player.reload_time >= 0 {
			player.reload_time -= delta
			if player.reload_time <= 0 {
				player.ammo = MAX_AMMO
			}
		}
		if player.invuln_time > 0 {
			player.invuln_time -= delta
		}
		if rl.IsMouseButtonPressed(rl.MouseButton.RIGHT) && !player.rolling && !player.is_on_floor {
			player.rolling = true
		}

		if player.rolling {
			player.roll_angle += 720 * delta
			if player.roll_angle > 360 {
				player.roll_angle = 0
				player.rolling = false
			}
		}

		force := mouse_pos - player_pos
		force.y *= -1
		player.recoil_vec = rl.Vector2Normalize(-force) * 18
		player.direction = linalg.atan2(force.y, force.x)
		player.flip = force.x < 0

		if player.velocity.y > 0 {
			player.is_on_floor = false
		}

		for block in blocks {
			b := block
			block_aabb := [2]Vec3{b.position - b.size / 2, b.position + b.size / 2}

			//vertical movement/collision
			velocity := Vec3{0, player.velocity.y, 0}
			new_pos := player.position + velocity * delta
			player_aabb_current := [2]Vec3{player.position - player.size / 2, player.position + player.size / 2}
			player_aabb := [2]Vec3{new_pos - player.size / 2, new_pos + player.size / 2}

			// if block_aabb[0].x < player_aabb[1].x &&
			//    block_aabb[0].y < player_aabb[1].y &&
			//    block_aabb[1].x > player_aabb[0].x &&
			//    block_aabb[1].y > player_aabb[0].y {
			if checkAABB(block_aabb, player_aabb) {
				if player.velocity.y > 0 && !block.isPlaform {
					player.position.y =
						block.position.y - (player.size.y / 2 + block.size.y / 2) - 0.01
					player.velocity.y = 0
				} else if player.velocity.y < 0 {
					if checkAABB(block_aabb, player_aabb_current) { continue }

					player.position.y =
						block.position.y + (player.size.y / 2 + block.size.y / 2) + 0.01
					// full stop on ground
					player.velocity.y = 0
					player.velocity.xy = rl.Vector2MoveTowards(player.velocity.xy, {}, 60 * delta)
					player.is_on_floor = true
				}
			}

			//horizontal movement/collision
			velocity = Vec3{player.velocity.x, 0, 0}
			new_pos = player.position + velocity * delta
			player_aabb = [2]Vec3{new_pos - player.size / 2, new_pos + player.size / 2}
			if !block.isPlaform && checkAABB(block_aabb, player_aabb) {
				if player.velocity.x > 0 {
					player.position.x =
						block.position.x - (player.size.x / 2 + block.size.x / 2) - 0.01
					player.velocity.x = 0
				} else if player.velocity.x < 0 {
					player.position.x =
						block.position.x + (player.size.x / 2 + block.size.x / 2) + 0.01
					player.velocity.x = 0
				}
			}
		}
	} else {
		player.rotation += 360 * delta
	}
	player.velocity = rl.Vector3ClampValue(player.velocity, 0, 50)
	player.position += player.velocity * delta

	if player.is_on_floor {
		player.rotation = 0
	} else {
		player.rotation += 250 * delta * (-1 if player.velocity.x > 0 else 1)
	}

	gun_vec := Vec3{0.7, 0.1, 0}
	if player.flip {
		gun_vec *= {1, -1, 1}
	}

	top_vec := Vec3{0, 0.15, 0}
	top_vec = rl.Vector3Transform(top_vec, rl.MatrixRotateZ(math.to_radians(player.rotation)))

	gun_vec = rl.Vector3Transform(gun_vec, rl.MatrixRotateZ(player.direction))

	player.shoot_point = player.position + top_vec + gun_vec
	// gunVec = rl.Vector3Transform(gunVec, rl.MatrixRotateZ(player.direction))


}

player_draw :: proc(using player: ^Player) {
	rl.rlPushMatrix()
	rl.rlTranslatef(position.x, player.position.y, player.position.z)
	rl.rlRotatef(rotation, 0, 0, 1)
	if flip {
		rl.rlScalef(-1, 1, 1)
	}
	rl.rlRotatef(player.roll_angle, 0, 1, 0)
	rl.DrawBillboard(camera, playerSprite, {}, 1, rl.WHITE)
	if flip {
		rl.rlScalef(-1, 1, 1)
	}
	rl.rlTranslatef(0, 0.15, 0)
	rl.rlRotatef(-rotation, 0, 0, 1)
	rl.rlRotatef(math.to_degrees(direction), 0, 0, 1)
	if flip {
		rl.rlScalef(1, -1, 1)
	}
	rl.DrawBillboard(camera, playerSpriteHand, {0.5, 0, 0}, 1, rl.WHITE)
	rl.rlPopMatrix()
}