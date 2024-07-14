package main

import "core:math"
import rand "core:math/rand"
import rl "raylib"

zombieTex: rl.Texture2D
ZOMBIE_FRAMES :: 4
ZOMBIE_FRAME_SIZE :: 16

Zombie :: struct {
	using position: Position,
	velocity:       Vec3,
	size:           Vec3,
	rotation:       f32,
	rotation_dir: 	f32,
	reaction_timer: f32,
	can_act:		bool,
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
	zombie.reaction_timer -= delta 
	if zombie.reaction_timer <= 0 {
		zombie.reaction_timer = rand.float32_range(2, 5)
		zombie.can_act = true
	}
	
	zombie.velocity += GRAVITY * delta

	diff := player.position - zombie.position
	zombie.flip = diff.x < 0

	if !zombie.is_dead {
		if player.invuln_time <= 0 && player.health > 0 && !player.rolling {
			if rl.Vector3LengthSqr(diff) < math.pow2_f32(zombie.size.x / 3 + player.size.x / 3) {
				player.health -= 10
				player.invuln_time = 1
				player.velocity += {math.sign(diff.x) * 7, 10, 0}
			}

			if zombie.can_act {
				zombie.can_act = false
				if zombie.is_on_floor && abs(diff.x) < 4 {

					if diff.y < 0 {
						zombie.position.y -= 0.3
					} else {
						zombie.velocity = rl.Vector3Normalize(diff) * 14 + {0, 4, 0}

					}
				}
			}
		}
		for block in blocks {
			b := block
			block_aabb := [2]Vec3{b.position - b.size / 2, b.position + b.size / 2}

			//vertical movement/collision
			velocity := Vec3{0, zombie.velocity.y, 0}
			new_pos := zombie.position + velocity * delta
			zombie_aabb := [2]Vec3{new_pos - zombie.size / 2, new_pos + zombie.size / 2}
			zombie_aabb_current := [2]Vec3{zombie.position - zombie.size / 2, zombie.position + zombie.size / 2}

			if checkAABB(zombie_aabb, block_aabb) {
				if zombie.velocity.y > 0 && !block.isPlaform {
					zombie.position.y =
						block.position.y - (zombie.size.y / 2 + block.size.y / 2) - 0.01
					zombie.velocity.y = 0
				} else if zombie.velocity.y < 0 {
					if checkAABB(block_aabb, zombie_aabb_current) { continue }
					
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
			if !block.isPlaform && checkAABB(zombie_aabb, block_aabb) {
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

			for &other in zombies {
				if &other == zombie {
					continue
				}
				if other.is_dead {
					continue
				}
				diff := other.position - zombie.position
				if rl.Vector3LengthSqr(diff) > math.pow2_f32(other.size.x / 2 + zombie.size.x / 2) { continue }
				zombie.velocity -= rl.Vector3Normalize(diff) * {0.2, 0, 0}
			}
		}
	} else {
		if zombie.rotation_dir == 0 {
			zombie.rotation_dir = rand.float32_range(-1, 1)
		}
		zombie.rotation += zombie.rotation_dir * 360 * delta
	}

	if zombie.velocity.y == 0 {
		d := diff.xy
		d.y = 0
		zombie.velocity.xy = rl.Vector2MoveTowards(zombie.velocity.xy, rl.Vector2Normalize(d) * 4, 50 * delta)
	}
	zombie.position += zombie.velocity * delta
}

zombie_draw :: proc(zombie: ^Zombie) {
	x := (zombie.frame % ZOMBIE_FRAMES) * ZOMBIE_FRAME_SIZE
	rl.rlPushMatrix()
	rl.rlTranslatef(zombie.x, zombie.y, zombie.z)
	if zombie.flip {
		rl.rlScalef(-1, 1, 1)
	}
	rl.rlRotatef(zombie.rotation, 0, 0, 1)
	rl.DrawBillboardRec(
		camera,
		zombieTex,
		rl.Rectangle{x = f32(x), y = 0, width = ZOMBIE_FRAME_SIZE, height = ZOMBIE_FRAME_SIZE},
		{},
		{1, 1},
		rl.WHITE,
	)
	rl.rlPopMatrix()
}

