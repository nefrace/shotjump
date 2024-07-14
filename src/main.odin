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

WIDTH : i32 = 800
HEIGHT : i32 = 600

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

playerSprite: rl.Texture2D
playerSpriteHand: rl.Texture2D

backgroundMesh: rl.Mesh
backgroundTexture: rl.Texture2D
backgroundMat: rl.Material

floorModel: rl.Model
ceilModel: rl.Model
wallModel: rl.Model
platformModel: rl.Model
pipeModel: rl.Model
shellSprite: rl.Texture

discard_shader : rl.Shader

@(export, link_name = "_main")
_main :: proc "c" () {
	ctx = runtime.default_context()
	context = ctx

	mem.arena_init(&mainMemoryArena, mainMemoryData[:])
	mem.arena_init(&tempAllocatorArena, tempAllocatorData[:])

	ctx.allocator = mem.arena_allocator(&mainMemoryArena)
	ctx.temp_allocator = mem.arena_allocator(&tempAllocatorArena)
	rl.SetConfigFlags(rl.ConfigFlags{.WINDOW_RESIZABLE})
	rl.InitWindow(i32(WIDTH), i32(HEIGHT), "ShotJump")
	rl.SetTargetFPS(60)
	WIDTH = rl.GetScreenWidth()
	HEIGHT = rl.GetScreenHeight()

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
	ceilModel = rl.LoadModel("assets/ceil.obj")
	wallModel = rl.LoadModel("assets/wall.obj")
	platformModel = rl.LoadModel("assets/platform.obj")
	pipeModel = rl.LoadModel("assets/pipe.obj")
	zombieTex = rl.LoadTexture("assets/zombie.png")
	shellSprite = rl.LoadTexture("assets/shell.png")
	playerSprite = rl.LoadTexture("assets/player.png")
	playerSpriteHand = rl.LoadTexture("assets/hand.png")
    bulletTex = rl.LoadTexture("assets/shot.png")
    boomTex = rl.LoadTexture("assets/boom.png")
    skullSprite = rl.LoadTexture("assets/skull.png")
	rl.rlDisableBackfaceCulling()
	discard_shader = rl.LoadShaderFromMemory(nil, discard_shader_text)

	newgame()
}

newgame :: proc() {
	bullets_init()
	skulls_init()

	player = Player{	
		health = 100,
		y = 2,
		ammo = MAX_AMMO,
		size = {1, 1, 1},
	}

	camera.position = Vec3{0, 0, 15}
	camera.target = player.position
	camera.up = Vec3{0, 1, 0}
	camera.fovy = 55
	camera.projection = rl.CameraProjection.PERSPECTIVE

	blocks = slice.into_dynamic(blocks_buffer[:])
	zombies = slice.into_dynamic(zombies_buf[:])


	ground := Block {
		position = Vec3{0, -10, 0},
		size     = Vec3{40, 20, 6},
	}
	ceiling := Block {
		position = Vec3{0, 26, 0},
		size     = Vec3{40, 20, 6},
	}

	append(&blocks, Block{position = {-19, 11, 0}, size = {2, 20, 2}})
	append(&blocks, Block{position = {19, 11, 0}, size = {2, 20, 2}})
	append(&blocks, ground)
	append(&blocks, ceiling)

	append(&blocks, Block{{0, 3.5, 0}, {5, 0.4, 1}, true})
	append(&blocks, Block{{9, 5, 0}, {5, 0.4, 1}, true})
	append(&blocks, Block{{-9, 5, 0}, {5, 0.4, 1}, true})
}

@(export, link_name = "step")
step :: proc "contextless" () {
	context = ctx
	update()
}

update :: proc() {
	if rl.IsWindowResized() {
		WIDTH = rl.GetScreenWidth()
		HEIGHT = rl.GetScreenHeight()
	}
	free_all(context.temp_allocator)

	delta := rl.GetFrameTime()
	delta = min(delta, 0.5)

	pipes_update(delta)

	player_update(&player, delta)
	if !player.is_dead {
		camera.position = player.position + Vec3{0, 0, 16}
		camera.target = player.position
	}

	bullets_update(delta)
	skulls_update(delta)


	#reverse for &zombie, i in zombies {
		zombie_update(&zombie, delta)
		if zombie.y < -20 {
			unordered_remove(&zombies, i)
		}
	}

	rl.BeginDrawing()
	rl.BeginShaderMode(discard_shader)
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
	pipes_draw()

	player_draw(&player)
	bullets_draw()
	skulls_draw()

	for &zombie in zombies {
		zombie_draw(&zombie)
	}

	for i in -10 ..< 10 {
		rl.DrawModel(floorModel, {f32(i) * 8, 0, 0}, 8, rl.WHITE)
		rl.DrawModel(ceilModel, {f32(i) * 8, 16, 0}, 8, rl.WHITE)
	}
	rl.DrawModel(wallModel, {-18, 0, 0}, 8, rl.WHITE)
	rl.rlPushMatrix()
	rl.rlSetCullFace(rl.CullMode.FRONT)
	rl.rlTranslatef(18, 0, 0)
	rl.rlScalef(-1, 1, 1)
	rl.DrawModel(wallModel, {0, 0, 0}, 8, rl.WHITE)
	rl.rlPopMatrix()
	rl.rlSetCullFace(rl.CullMode.BACK)

	rl.EndShaderMode()
	rl.EndMode3D()

	bullets_pos := Vec2{4, 4}
	if player.ammo > 0 {
		for i in 0..<player.ammo {
			rl.DrawTextureEx(shellSprite, bullets_pos + {f32(i) * 30, 0}, 0, 4, rl.WHITE)
		}
	} else if player.reload_time > 0 {
		rl.DrawText("RELOADING", i32(bullets_pos.x), i32(bullets_pos.y), 30, rl.WHITE)
		rl.rlSetLineWidth(2)
		rl.DrawLineV(bullets_pos + {0, 36}, bullets_pos + {player.reload_time / 1.2 * 180, 36}, rl.WHITE)
	}

	text := rl.TextFormat("KILLS: %d", player.kills)
	w := rl.MeasureText(text, 30)
	rl.DrawText(text, WIDTH / 2 - w / 2, 4, 30, rl.WHITE)

	if player.is_dead {
		if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
			newgame()
			return
		}
		text : cstring = "GAME OVER" 
		text2 : cstring = "PRESS LEFT MOUSE BUTTON TO RESTART"
		size := rl.MeasureTextEx(rl.GetFontDefault(), text, 50, 4)
		size2 := rl.MeasureTextEx(rl.GetFontDefault(), text2, 20, 4)
		rl.DrawTextEx(rl.GetFontDefault(), text, {f32(WIDTH) / 2 - size.x / 2, f32(HEIGHT) / 2 - size.y / 2}, 50, 4, rl.RED)
		rl.DrawTextEx(rl.GetFontDefault(), text2, {f32(WIDTH) / 2 - size2.x / 2, f32(HEIGHT) / 2 - size2.y / 2 + 60}, 20, 4, rl.RED)
	}

	rl.DrawRectangleV(bullets_pos + {0, 40}, {198, 30}, rl.BLACK)
	rl.DrawRectangleV(bullets_pos + {2, 42}, {player.health / 100 * 194, 26}, rl.RED)

	rl.EndDrawing()
}

discard_shader_text :: `
#version 100

precision mediump float;

// Input vertex attributes (from vertex shader)
varying vec2 fragTexCoord;
varying vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;

void main(void) {
  vec4 textureColor = texture2D(texture0, fragTexCoord);
  if (textureColor.a < 0.5) 
    discard;
  else
    gl_FragColor = textureColor;
}
`

discard_shader_text_gl3 :: `
#version 330 es

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Output fragment color
out vec4 finalColor;

void main()
{
    vec4 texelColor = texture(texture0, fragTexCoord);
    if (texelColor.a == 0.0) discard;
    finalColor = texelColor * fragColor * colDiffuse;
}
`