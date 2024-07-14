package main

import rl "raylib"
import "core:math"
import rand "core:math/rand"
import "core:slice"
import "core:fmt"
import "core:log"

bulletTex : rl.Texture2D

Bullet :: struct {
    using position: Position,
    velocity: Vec3,
    size: Vec3,
}

boomTex : rl.Texture2D 

BOOM_TEX_FRAMES :: 4
BOOM_TEX_FRAME_SIZE :: 16
Boom :: struct {
    using position: Position,
    scale: f32,
    timer: f32,
    frame: i8,
}

bullets_buf : [256]Bullet
bullets : [dynamic]Bullet

booms_buf : [256]Boom
booms : [dynamic]Boom


bullets_init :: proc() {
    bullets = slice.into_dynamic(bullets_buf[:])
    booms = slice.into_dynamic(booms_buf[:])
}

bullet_spawn :: proc(pos: Vec3, velocity: Vec3) {
    append(&bullets, Bullet{
        position = pos,
        size = {0.5, 0.5, 0.5},
        velocity = velocity
    })
}

boom_spawn :: proc(pos: Vec3, scale: f32 = 1) {
    append(&booms, Boom{
        position = pos + {0, 0, 1},
        scale = scale
    })
}

bullets_update :: proc(delta: f32) {
    loop: #reverse for &bullet, i in bullets {
        bullet.position += bullet.velocity * delta 
        bullet.velocity = rl.Vector3MoveTowards(bullet.velocity, {}, 70 * delta)
    
        if rl.Vector3LengthSqr(bullet.velocity) < 0.04 {
            unordered_remove(&bullets, i)
            continue
        }

        for block in blocks {
            b := block
            block_aabb := [2]Vec3{b.position - b.size / 2, b.position + b.size / 2}

            //vertical movement/collision
            velocity := Vec3{0, player.velocity.y, 0}
            bullet_aabb := [2]Vec3{bullet.position - bullet.size / 8, bullet.position + bullet.size / 8}

            if block_aabb[0].x < bullet_aabb[1].x &&
            block_aabb[0].y < bullet_aabb[1].y &&
            block_aabb[1].x > bullet_aabb[0].x &&
            block_aabb[1].y > bullet_aabb[0].y {
                boom_spawn(bullet.position)
                unordered_remove(&bullets, i)
                continue loop
            }
        }

        for &zombie in zombies {
            diff := bullet.position - zombie.position
            if rl.Vector3LengthSqr(diff) < math.pow((bullet.size.x / 2 + zombie.size.x / 2), 2) {
                boom_spawn(bullet.position)
                zombie.is_dead = true
                player.kills += 1
                zombie.velocity = {
                    math.sign(diff.x) * 5,
                    10,
                    10 if rand.float32() < 0.5 else -10
                }
                unordered_remove(&bullets, i)
                continue loop
            }
        }
        for &skull in skulls {
            diff := bullet.position - skull.position
            if rl.Vector3LengthSqr(diff) < math.pow((bullet.size.x / 1.4 + skull.size.x / 1.4), 2) {
                boom_spawn(bullet.position)
                skull.is_dead = true
                player.kills += 1
                skull.velocity = {
                    math.sign(diff.x) * 5,
                    10,
                    10 if rand.float32() < 0.5 else -10
                }
                unordered_remove(&bullets, i)
                continue loop
            }
        }
    }

    #reverse for &boom, i in booms {
        boom.timer += delta 
        if boom.timer > 0.1 {
            boom.timer = 0
            boom.frame += 1
            if boom.frame >= 4 {
                unordered_remove(&booms, i)
                continue
            }
        }
    }
}

bullets_draw :: proc() {
    for &bullet in bullets {
        rl.rlPushMatrix()
        rl.rlTranslatef(bullet.x, bullet.y, bullet.z) 
        rl.rlRotatef(math.to_degrees(math.atan2(bullet.velocity.y, bullet.velocity.x)), 0, 0, 1)
        rl.DrawBillboard(camera, bulletTex, {}, 1, rl.WHITE)
        rl.rlPopMatrix()
    }

    for &boom in booms {
        rl.DrawBillboardRec(camera, boomTex, rl.Rectangle{x = f32(boom.frame) * BOOM_TEX_FRAME_SIZE, y = 0, width = BOOM_TEX_FRAME_SIZE, height = BOOM_TEX_FRAME_SIZE}, boom.position, boom.scale, rl.WHITE)
    }
}