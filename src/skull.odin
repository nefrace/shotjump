package main

import rl "raylib"
import "core:math"
import "core:math/rand"
import "core:slice"


Skull :: struct {
    using position: Position,
    velocity: Vec3,
    size: Vec3,
    is_dead: bool,
    flip: bool,
    rotation: f32,
    shoot_timer: f32,
    frame: i32
}

SkullBullet :: struct {
    using bullet: Bullet
}

skulls_buf: [64]Skull
skulls: [dynamic]Skull

skull_bullets_buf: [64]SkullBullet
skull_bullets: [dynamic]SkullBullet

skullSprite: rl.Texture

skulls_init :: proc() {
    skulls = slice.into_dynamic(skulls_buf[:])
    skull_bullets = slice.into_dynamic(skull_bullets_buf[:])
}

skull_spawn :: proc(pos: Vec3) {
    append(&skulls, Skull{
        position = pos,
        velocity = {0, -5, 0},
        size = {0.7, 0.7, 0.7},
        shoot_timer = rand.float32_range(5, 10)
    })
}
skull_bullet_spawn :: proc(pos: Vec3, velocity: Vec3) {
    append(&skull_bullets, SkullBullet{
        position = pos,
        size = {0.5, 0.5, 0.5},
        velocity = velocity
    })
}


skulls_update :: proc(delta: f32) {
    #reverse for &skull, i in skulls {
        if !skull.is_dead {
            diff := player.position - skull.position
            skull.frame = 0
            skull.shoot_timer -= delta
            if skull.shoot_timer < 0.5 {
                skull.frame = 1
                if skull.shoot_timer <= 0 {
                    skull_bullet_spawn(skull.position, rl.Vector3Normalize(diff) * 10)
                    skull.shoot_timer = rand.float32_range(3, 5)
                }
            }
            skull.velocity += rl.Vector3Normalize(diff) * 5 * delta
            skull.velocity = rl.Vector3ClampValue(skull.velocity, 0, 3)
            skull.rotation = math.atan2(diff.y, diff.x)
            skull.flip = diff.x < 0


            for block in blocks {
                b := block
                block_aabb := [2]Vec3{b.position - b.size / 2, b.position + b.size / 2}

                //vertical movement/collision
                velocity := Vec3{0, player.velocity.y, 0}
                new_pos := skull.position + velocity * delta
                skull_aabb := [2]Vec3{new_pos - skull.size / 2, new_pos + skull.size / 2}

                // if block_aabb[0].x < skull_aabb[1].x &&
                //    block_aabb[0].y < skull_aabb[1].y &&
                //    block_aabb[1].x > skull_aabb[0].x &&
                //    block_aabb[1].y > skull_aabb[0].y {
                if !block.isPlaform && checkAABB(block_aabb, skull_aabb) {
                    if skull.velocity.y > 0 && !block.isPlaform {
                        skull.position.y =
                            block.position.y - (skull.size.y / 2 + block.size.y / 2) - 0.01
                        skull.velocity.y = -skull.velocity.y / 3
                    } else if skull.velocity.y < 0 {

                        skull.position.y =
                            block.position.y + (skull.size.y / 2 + block.size.y / 2) + 0.01
                        // full stop on ground
                        skull.velocity.y = -skull.velocity.y / 3
                        skull.velocity.xy = rl.Vector2MoveTowards(skull.velocity.xy, {}, 60 * delta)
                    }
                }

                //horizontal movement/collision
                velocity = Vec3{skull.velocity.x, 0, 0}
                new_pos = skull.position + velocity * delta
                skull_aabb = [2]Vec3{new_pos - skull.size / 2, new_pos + skull.size / 2}
                if !block.isPlaform && checkAABB(block_aabb, skull_aabb) {
                    if skull.velocity.x > 0 {
                        skull.position.x =
                            block.position.x - (skull.size.x / 2 + block.size.x / 2) - 0.01
                        skull.velocity.x = -skull.velocity.x / 3
                    } else if skull.velocity.x < 0 {
                        skull.position.x =
                            block.position.x + (skull.size.x / 2 + block.size.x / 2) + 0.01
                        skull.velocity.x = -skull.velocity.x / 3
                    }
                }
            }
        } else {
            skull.velocity += GRAVITY * delta
            skull.rotation += 600 * delta
            if skull.position.y < -20 {
                unordered_remove(&skulls, i)
            }
        }
        skull.position += skull.velocity * delta
        
    }
    skull_bullets_update(delta)
}




skull_bullets_update :: proc(delta: f32) {
    loop: #reverse for &bullet, i in skull_bullets {
        bullet.position += bullet.velocity * delta 
    

        for block in blocks {
            b := block
            block_aabb := [2]Vec3{b.position - b.size / 2, b.position + b.size / 2}

            //vertical movement/collision
            velocity := Vec3{0, player.velocity.y, 0}
            bullet_aabb := [2]Vec3{bullet.position - bullet.size / 2, bullet.position + bullet.size / 2}

            if checkAABB(bullet_aabb, block_aabb) {
                boom_spawn(bullet.position)
                unordered_remove(&skull_bullets, i)
                continue loop
            }

            if !player.is_dead && player.invuln_time <= 0 && !player.rolling {
                diff := bullet.position - player.position
                if rl.Vector3LengthSqr(diff) < math.pow((bullet.size.x / 2 + player.size.x / 3), 2) {
                    boom_spawn(bullet.position)
                    player.health -= 20
                    player.invuln_time = 1
                    player.velocity -= {math.sign(diff.x) * 2, 6, 0}
                    unordered_remove(&skull_bullets, i)
                }
            }
        }
    }
}


skulls_draw :: proc() {
    for skull in skulls {
        x := skull.frame * 16
        rl.rlPushMatrix()
        rl.rlTranslatef(skull.x, skull.y, skull.z)
        rl.rlRotatef(math.to_degrees(skull.rotation), 0, 0, 1)
        if skull.flip {
            rl.rlScalef(1, -1, 1)
        }
        rl.DrawBillboardRec(
            camera,
            skullSprite,
            rl.Rectangle{x = f32(x), y = 0, width = 16, height = 16},
            {},
            {1, 1},
            rl.WHITE,
        )
        rl.rlPopMatrix()
    }


    for &bullet in skull_bullets {
        rl.rlPushMatrix()
        rl.rlTranslatef(bullet.x, bullet.y, bullet.z) 
        rl.rlRotatef(math.to_degrees(math.atan2(bullet.velocity.y, bullet.velocity.x)), 0, 0, 1)
        rl.DrawBillboard(camera, bulletTex, {}, 1, rl.WHITE)
        rl.rlPopMatrix()
    }
}