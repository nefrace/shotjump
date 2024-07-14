package main

import "core:math"
import rl "raylib"

zombieTex: rl.Texture2D
ZOMBIE_FRAMES :: 4
ZOMBIE_FRAME_SIZE :: 16

Zombie :: struct {
	using position: Position,
	velocity:       Vec3,
	size:           Vec3,
	rotation:       f32,
	is_dead:        bool,
	is_on_floor:    bool,
	flip:           bool,
	frame:          i8,
	frameTimer:     f32,
}

zombies_buf: [256]Zombie
zombies: [dynamic]Zombie

zombie_spawn :: proc(pos: Vec3) {
	append(&zombies, Zombie{position = pos, size = {1, 1, 1}})
}

zombie_update :: proc(zombie: ^Zombie, delta: f32) {
	zombie.frameTimer += delta
	if zombie.frameTimer > 0.3 {
		zombie.frameTimer = 0
		zombie.frame += 1
		if zombie.frame >= ZOMBIE_FRAMES {
			zombie.frame = 0
		}
	}
	zombie.velocity += GRAVITY * delta

	diff := player.position - zombie.position
	zombie.flip = diff.x < 0

	if !zombie.is_dead {
		for block in blocks {
			b := block
			block_aabb := [2]Vec3{b.position - b.size / 2, b.position + b.size / 2}

			//vertical movement/collision
			velocity := Vec3{0, zombie.velocity.y, 0}
			new_pos := zombie.position + velocity * delta
			zombie_aabb := [2]Vec3{new_pos - zombie.size / 2, new_pos + zombie.size / 2}

			if block_aabb[0].x < zombie_aabb[1].x &&
			   block_aabb[0].y < zombie_aabb[1].y &&
			   block_aabb[1].x > zombie_aabb[0].x &&
			   block_aabb[1].y > zombie_aabb[0].y {
				if zombie.velocity.y > 0 {
					zombie.position.y =
						block.position.y - (zombie.size.y / 2 + block.size.y / 2) - 0.01
					zombie.velocity.y = 0
				} else if zombie.velocity.y < 0 {
					zombie.position.y =
						block.position.y + (zombie.size.y / 2 + block.size.y / 2) + 0.01
					// full stop on ground
					zombie.velocity.y = 0
					zombie.velocity.xy = rl.Vector2MoveTowards(zombie.velocity.xy, {}, 40 * delta)
					zombie.is_on_floor = true
				}
			}

			//horizontal movement/collision
			velocity = Vec3{zombie.velocity.x, 0, 0}
			new_pos = zombie.position + velocity * delta
			zombie_aabb = [2]Vec3{new_pos - zombie.size / 2, new_pos + zombie.size / 2}
			if block_aabb[0].x < zombie_aabb[1].x &&
			   block_aabb[0].y < zombie_aabb[1].y &&
			   block_aabb[1].x > zombie_aabb[0].x &&
			   block_aabb[1].y > zombie_aabb[0].y {
				if zombie.velocity.x > 0 {
					zombie.position.x =
						block.position.x - (zombie.size.x / 2 + block.size.x / 2) - 0.01
					zombie.velocity.x = 0
				} else if zombie.velocity.x < 0 {
					zombie.position.x =
						block.position.x + (zombie.size.x / 2 + block.size.x / 2) + 0.01
					zombie.velocity.x = 0
				}
			}
		}
	}

	if zombie.velocity.y == 0 {
		d := rl.Vector2Normalize(diff.xy)
		d.y = 0
		zombie.velocity.xy = rl.Vector2MoveTowards(zombie.velocity.xy, d * 4, 50 * delta)
	}
	zombie.position += zombie.velocity * delta
}

zombie_draw :: proc(zombie: ^Zombie) {
	x := (zombie.frame % ZOMBIE_FRAMES) * ZOMBIE_FRAME_SIZE
	rl.DrawBillboardRec(
		camera,
		zombieTex,
		rl.Rectangle{x = f32(x), y = 0, width = ZOMBIE_FRAME_SIZE, height = ZOMBIE_FRAME_SIZE},
		zombie.position,
		{1, 1},
		rl.WHITE,
	)
}

