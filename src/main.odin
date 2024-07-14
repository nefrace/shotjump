package main

import "core:runtime"
// import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:slice"
// import rl "vendor:raylib"
import rl "raylib"


foreign import "odin_env"

// @(default_calling_convention="c")
// foreign odin_env {
//     @(link_name="wasm_testing")
//     wasm_testing :: proc() ---
// }

ctx: runtime.Context

tempAllocatorData: [mem.Megabyte * 4]byte
tempAllocatorArena: mem.Arena

mainMemoryData: [mem.Megabyte * 16]byte
mainMemoryArena: mem.Arena

timer: f32

GRAVITY :: Vec3{0, -40, 0}

player := Player{}
camera: rl.Camera3D

Block :: struct {
	using position: Position,
	size:           Vec3,
	isPlaform:      bool,
}

Platform :: Block

blocks_buffer: [256]Block
blocks: [dynamic]Block


backgroundMesh: rl.Mesh
backgroundTexture: rl.Texture2D
backgroundMat: rl.Material

floorModel: rl.Model
wallModel: rl.Model
platformModel: rl.Model

@(export, link_name = "_main")
_main :: proc "c" () {
	ctx = runtime.default_context()
	context = ctx

	mem.arena_init(&mainMemoryArena, mainMemoryData[:])
	mem.arena_init(&tempAllocatorArena, tempAllocatorData[:])

	ctx.allocator = mem.arena_allocator(&mainMemoryArena)
	ctx.temp_allocator = mem.arena_allocator(&tempAllocatorArena)
	rl.InitWindow(800, 600, "test")
	rl.SetTargetFPS(60)
	rand.set_global_seed(1)

	checkerImage := rl.GenImageChecked(
		64,
		64,
		4,
		4,
		rl.ColorFromHSV(280, 0.5, 0.4),
		rl.ColorFromHSV(280, 0.5, 0.5),
	)
	backgroundTexture = rl.LoadTextureFromImage(checkerImage)
	rl.UnloadImage(checkerImage)
	backgroundMesh = rl.GenMeshPlane(1, 1, 2, 2)
	backgroundMat = rl.LoadMaterialDefault()
	rl.SetMaterialTexture(&backgroundMat, rl.MaterialMapIndex.ALBEDO, backgroundTexture)

	floorModel = rl.LoadModel("assets/floor.obj")
	wallModel = rl.LoadModel("assets/wall.obj")
	platformModel = rl.LoadModel("assets/platform.obj")
	zombieTex = rl.LoadTexture("assets/zombie.png")


	player.y = 2
	player.size = {1, 1, 1}
	player.sprite = rl.LoadTexture("assets/player.png")
	player.spr_hand = rl.LoadTexture("assets/hand.png")

	camera.position = Vec3{0, 0, 15}
	camera.target = player.position
	camera.up = Vec3{0, 1, 0}
	camera.fovy = 40
	camera.projection = rl.CameraProjection.PERSPECTIVE

	blocks = slice.into_dynamic(blocks_buffer[:])
	zombies = slice.into_dynamic(zombies_buf[:])


	ground := Block {
		position = Vec3{0, -10, 0},
		size     = Vec3{40, 20, 6},
	}

	append(&blocks, Block{position = {-19, 11, 0}, size = {2, 20, 2}})
	append(&blocks, Block{position = {19, 11, 0}, size = {2, 20, 2}})
	append(&blocks, ground)

	append(&blocks, Block{{0, 3.5, 0}, {5, 0.4, 1}, true})
	append(&blocks, Block{{9, 5, 0}, {5, 0.4, 1}, true})
	append(&blocks, Block{{-9, 5, 0}, {5, 0.4, 1}, true})

	zombie_spawn({0, 5, 0})

	rl.rlDisableBackfaceCulling()
	// wasm_testing()
}

@(export, link_name = "step")
step :: proc "contextless" () {
	context = ctx
	update()
}

update :: proc() {
	free_all(context.temp_allocator)

	delta := rl.GetFrameTime()

	player_update(&player, delta)
	camera.position = player.position + Vec3{0, 0, 16}
	camera.target = player.position

	rl.BeginDrawing()
	rl.BeginMode3D(camera)

	rl.rlPushMatrix()
	rl.rlTranslatef(0, 0, -20)
	rl.rlRotatef(90, 1, 0, 0)
	rl.rlScalef(100, 100, 100)
	rl.DrawMesh(backgroundMesh, backgroundMat, rl.Matrix(1))
	rl.rlPopMatrix()

	for block in blocks {
		// rl.DrawCubeV(block.position, block.size, rl.GRAY)
		if block.isPlaform {
			rl.DrawModel(platformModel, block.position + {0, 0.5, 0} * block.size, 5, rl.WHITE)
		}
	}

	for &zombie in zombies {
		zombie_update(&zombie, delta)
	}

	m := rl.MatrixRotate({1, 1, 1}, 0.9)
	vec := rl.Vector3Transform({5, 0, 0}, m)
	rl.DrawSphere(vec, .5, rl.YELLOW)


	rl.rlPushMatrix()
	rl.rlTranslatef(player.position.x, player.position.y, player.position.z)
	rl.rlRotatef(player.rotation, 0, 0, 1)
	if player.flip {
		rl.rlScalef(-1, 1, 1)
	}
	rl.DrawBillboard(camera, player.sprite, {}, 1, rl.WHITE)
	if player.flip {
		rl.rlScalef(-1, 1, 1)
	}
	rl.rlTranslatef(0, 0.15, 0)
	rl.rlRotatef(-player.rotation, 0, 0, 1)
	rl.rlRotatef(math.to_degrees(player.direction), 0, 0, 1)
	if player.flip {
		rl.rlScalef(1, -1, 1)
	}
	rl.DrawBillboard(camera, player.spr_hand, {0.5, 0, 0}, 1, rl.WHITE)
	rl.rlPopMatrix()

	for &zombie in zombies {
		zombie_draw(&zombie)
	}

	for i in -10 ..< 10 {
		rl.DrawModel(floorModel, {f32(i) * 8, 0, 0}, 8, rl.WHITE)
	}
	rl.DrawModel(wallModel, {-18, 0, 0}, 8, rl.WHITE)
	rl.rlPushMatrix()
	rl.rlSetCullFace(rl.CullMode.FRONT)
	rl.rlTranslatef(18, 0, 0)
	rl.rlScalef(-1, 1, 1)
	rl.DrawModel(wallModel, {0, 0, 0}, 8, rl.WHITE)
	rl.rlPopMatrix()
	rl.rlSetCullFace(rl.CullMode.BACK)


	// start := player.position.xy
	// end := player.position.xy + {player.jump_force.x, 0}
	// step := abs(end.x - start.x) / 30
	// dir := math.sign(end.x - start.x)
	// jf := Vec2{abs(player.jump_force.x), player.jump_force.y}

	// if player.is_dragging {
	// 	trajectory_y : f32 = 0
	// 	i := 0
	// 	trajectory: for {
	// 		x := step * f32(i)
	// 		angle := rl.Vector2Angle(jf, {1, 0})
	// 		len := rl.Vector2Length(jf)
	// 		angtan := math.tan(angle)
	// 		angcos := math.cos(angle)
	// 		cosquare := math.pow(angcos, 2)
	// 		y := ((x * angtan) + (GRAVITY.y * x * x) / (2 * len * len * cosquare))

	// 		rl.DrawSphere({player.position.x + x * dir, player.position.y + y, 0}, 0.1, rl.RED)
	// 		trajectory_y = y
	// 		i += 1
	// 		pos := player.position.xy + {x * dir, y}
	// 		for block in blocks {
	// 			if rl.CheckCollisionPointRec(pos, rl.Rectangle{x = block.position.x - block.size.x / 2, y = block.position.y - block.size.y / 2, width = block.size.x, height = block.size.y}) {
	// 				break trajectory
	// 			}
	// 		}
	// 		if i > 50 { break }
	// 	}
	// }


	rl.EndMode3D()

	rl.DrawText(
		rl.TextFormat("%f \t %f", player.velocity.x, player.velocity.y),
		0,
		0,
		20,
		rl.RAYWHITE,
	)
	rl.DrawText(
		rl.TextFormat("%f \t %f", player.position.x, player.position.y),
		0,
		20,
		20,
		rl.RAYWHITE,
	)
	rl.DrawText(rl.TextFormat("is on floor: %v", player.is_on_floor), 0, 40, 20, rl.RAYWHITE)
	rl.EndDrawing()


}

