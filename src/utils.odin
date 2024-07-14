package main

import rl "raylib"


Vec3 :: [3]f32 
Vec3i :: [3]i32

Vec2 :: [2]f32
Vec2i :: [2]i32


checkAABB :: proc(a: [2]Vec3, b: [2]Vec3) -> bool {
    return rl.CheckCollisionRecs(
        rl.Rectangle{x = a[0].x, y = a[0].y, width = a[1].x - a[0].x, height = a[1].y - a[0].y},
        rl.Rectangle{x = b[0].x, y = b[0].y, width = b[1].x - b[0].x, height = b[1].y - b[0].y},
    )

}