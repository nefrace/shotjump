package main

import rl "raylib"
import rand "core:math/rand"


max_enemies := 5
kill_goal : i32 = 6
max_timer : f32 = 9
min_timer : f32 = 6


Pipe :: struct {
    using position: Position,
    spawn_timer: f32
}

pipes := [3]Pipe{
    {position = {-9, 16, 0}, spawn_timer = 3},
    {position = {0, 16, 0}, spawn_timer = 5},
    {position = {9, 16, 0}, spawn_timer = 7}
}


pipes_update :: proc(delta: f32) {
    if player.kills >= kill_goal {
        max_enemies += 1
        kill_goal += 5 + (kill_goal / 4)
        max_timer = max(max_timer - 0.3, 4)
        min_timer = max(min_timer - 0.3, 2)
    }
    for &pipe in pipes {
        pipe.spawn_timer -= delta
        if pipe.spawn_timer <= 0 {
            pipe.spawn_timer += rand.float32_range(6, 9)
            if len(zombies) + len(skulls) < max_enemies {
                if rand.float32() < 0.85 {
                    zombie_spawn(pipe.position + {0, -1, 0})
                } else {
                    skull_spawn(pipe.position + {0, -1, 0})
                }
            }
        }
    }
}

pipes_draw :: proc() {
    for pipe in pipes {
        rl.rlPushMatrix()
        rl.rlTranslatef(pipe.x, pipe.y, pipe.z)
        rl.rlRotatef(180, 0, 0, 1)
        rl.DrawModel(pipeModel, {}, 2, rl.WHITE)
        rl.rlPopMatrix()
    }
}