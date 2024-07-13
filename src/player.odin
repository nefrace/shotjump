package main

import rl "raylib"
import "core:math/linalg"

Position :: [3]f32 

Player :: struct {
    using position: Position,
    velocity: Vec3,
    size: Vec3,
	direction: f32,
	flip: bool,
    is_on_floor: bool,
    recoil_vec: Vec2,
	sprite: rl.Texture,
	spr_hand: rl.Texture
}

player_update :: proc(player: ^Player, delta: f32) {
	player.velocity += GRAVITY * delta


	mouse_pos := rl.GetMousePosition()
	player_pos := rl.GetWorldToScreen(player.position, camera)
	ray := rl.GetMouseRay(mouse_pos, camera)

	if rl.IsMouseButtonReleased(rl.MouseButton.LEFT) {
			player.velocity.xy = player.recoil_vec
	}

	force := mouse_pos - player_pos
	force.y *= -1
	player.recoil_vec = rl.Vector2Normalize(-force) * 20
	player.direction = linalg.atan2(force.y, force.x)
	player.flip = force.x < 0
	

	for block in blocks {
		b := block 
		block_aabb := [2]Vec3{b.position - b.size / 2, b.position + b.size / 2}

		//vertical movement/collision
		velocity := Vec3{0, player.velocity.y, 0}
		new_pos := player.position + velocity * delta
		player_aabb := [2]Vec3{new_pos - player.size / 2, new_pos + player.size / 2}

		if block_aabb[0].x < player_aabb[1].x &&
			block_aabb[0].y < player_aabb[1].y && 
			block_aabb[1].x > player_aabb[0].x &&
			block_aabb[1].y > player_aabb[0].y 
			{
			if player.velocity.y > 0 {
				player.position.y = block.position.y - (player.size.y / 2 + block.size.y / 2) - 0.01
				player.velocity.y = 0
			} else if player.velocity.y < 0 {
				player.position.y = block.position.y + (player.size.y / 2 + block.size.y / 2) + 0.01
				// full stop on ground
				player.velocity.xy = {0, 0}
			}
		}

		//horizontal movement/collision
		velocity = Vec3{player.velocity.x, 0, 0}
		new_pos = player.position + velocity * delta
		player_aabb = [2]Vec3{new_pos - player.size / 2, new_pos + player.size / 2}
		if block_aabb[0].x < player_aabb[1].x &&
			block_aabb[0].y < player_aabb[1].y && 
			block_aabb[1].x > player_aabb[0].x &&
			block_aabb[1].y > player_aabb[0].y 
			{
			if player.velocity.x > 0 {
				player.position.x = block.position.x - (player.size.x / 2 + block.size.x / 2) - 0.01
				player.velocity.x = 0
			} else if player.velocity.x < 0 {
				player.position.x = block.position.x + (player.size.x / 2 + block.size.x / 2) + 0.01
				player.velocity.x = 0
			}
		}
	}
	player.position += player.velocity * delta
}
