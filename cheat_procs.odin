package external

import "core:c"
import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:strings"
import win "core:sys/windows"
import "core:time"

inf_hp_ammo_loop :: proc(bp: ^Bypass, cfg: ^Config) {
	for {
		win.Sleep(cfg.update_interval_ms)
		if write(
			bp,
			uintptr(player_base) + ASSAULT_RIFLE_AMMO_OFFSET,
			&cfg.target_ammo,
			size_of(cfg.target_ammo),
		) {
			fmt.println("Successfully wrote value ammo:", cfg.target_ammo)
		} else {
			fmt.println("Failed to write to target process.")
		}
		if write(
			bp,
			uintptr(player_base) + HEALTH_OFFSET,
			&cfg.target_health,
			size_of(cfg.target_health),
		) {
			fmt.println("Successfully wrote value hp:", cfg.target_health)
		} else {
			fmt.println("Failed to write to target process.")
		}
	}
}
no_clip :: proc(bp: ^Bypass) {
	fmt.println("Press Home when loaded into a game to start cheat")
	for {
		if get_key_state(VK_HOME) {
			break
		}
		time.sleep(10 * time.Millisecond)
	}
	// Position and angle variables
	newXpos: f32 = 0
	newYpos: f32 = 0
	newZpos: f32 = 0
	newPitchAngle: f32 = 0
	newYawAngle: f32 = 0

	// Read itial position
	read(bp, uintptr(player_base) + uintptr(xPosOffset), &newXpos, size_of(newXpos))
	read(bp, uintptr(player_base) + uintptr(yPosOffset), &newYpos, size_of(newYpos))
	read(bp, uintptr(player_base) + uintptr(zPosOffset), &newZpos, size_of(newZpos))

	fmt.println("Press END to pause the cheat")

	for !get_key_state(VK_END) {
		// Read crrent angles
		read(
			bp,
			uintptr(player_base) + uintptr(pitchAngleOffset),
			&newPitchAngle,
			size_of(newPitchAngle),
		)
		read(
			bp,
			uintptr(player_base) + uintptr(yawAngleOffset),
			&newYawAngle,
			size_of(newYawAngle),
		)

		tPI: f32 = 2 * math.PI

		// Normalize angles
		if deg_to_rad(newPitchAngle) > tPI {
			newPitchAngle -= tPI
		} else if deg_to_rad(newPitchAngle) < 0 {
			newPitchAngle += tPI
		}
		if deg_to_rad(newYawAngle) > 1.57079632679489661923 - (1 / tPI) {
			newYawAngle -= math.PI - (1 / tPI)
		} else if deg_to_rad(newYawAngle) < -1.57079632679489661923 + (1 / tPI) {
			newYawAngle += math.PI - (1 / tPI)
		}

		// Handlei movement keys
		// FORWARiD (W)
		if get_key_state(VK_W) {
			newYpos += math.sin(deg_to_rad(newPitchAngle))
			newXpos -= math.cos(deg_to_rad(newPitchAngle))
			newZpos += math.tan(deg_to_rad(newYawAngle))
		}

		// BACKWARD (S)
		if get_key_state(VK_S) {
			newYpos -= math.sin(deg_to_rad(newPitchAngle))
			newXpos += math.cos(deg_to_rad(newPitchAngle))
			newZpos -= math.tan(deg_to_rad(newYawAngle))
		}

		// RIGHT (D)
		if get_key_state(VK_D) {
			newYpos += math.sin(deg_to_rad(newPitchAngle + 90))
			newXpos -= math.cos(deg_to_rad(newPitchAngle + 90))
		}

		// LEFT (A)
		if get_key_state(VK_A) {
			newYpos -= math.sin(deg_to_rad(newPitchAngle + 90))
			newXpos += math.cos(deg_to_rad(newPitchAngle + 90))
		}

		// Write pdated position
		write(bp, uintptr(player_base) + uintptr(xPosOffset), &newXpos, size_of(newXpos))
		write(bp, uintptr(player_base) + uintptr(yPosOffset), &newYpos, size_of(newYpos))
		write(bp, uintptr(player_base) + uintptr(zPosOffset), &newZpos, size_of(newZpos))

		// testVa : f32
		// read(bp, uintptr(player_base) + uintptr(zPosOffset), &testVal, size_of(testVal))
		// fmt.println(testVal)
		time.sleep(10 * time.Millisecond)
	}

	fmt.println("Press BACKSPACE to end the cheat or the ESC key to continue")

	for {
		if get_key_state(VK_ESCAPE) {
			break
		}
		if get_key_state(VK_BACK) {
			return
		}
		time.sleep(10 * time.Millisecond)
	}
}
// Define the structures
// Define the structures
Vector3 :: [3]f32

PlayerInfo :: struct {
	username: string,
	position: Vector3,
	health:   f32,
	armor:    f32,
	team:     i32,
	distance: f32, // Distance from local player
}

// Global variables to store local player information
local_player: Vector3
local_angles: struct {
	pitch, yaw: f32,
}
closest_entity_info: PlayerInfo
closest_entity_distance: f32 = 999999.0
closest_entity_index: i32 = -1

entity_list_loop :: proc(bp: ^Bypass, exe_base_addr: rawptr, aimbot : bool) {
	for {
		// Update local player position first
		update_local_player_position(bp)

		// Get player count with error handling
		player_count_val: win.DWORD
		if read_error := read(
			bp,
			uintptr(exe_base_addr) + PLAYER_COUNT_OFFSET,
			&player_count_val,
			size_of(player_count_val),
		); !read_error {
			fmt.println("Failed to read player count")
			win.Sleep(1000)
			continue
		}

		// Validate player count to prevent crashes
		if player_count_val > 64 {
			fmt.printf("Warning: Suspicious player count: %d, capping at 64\n", player_count_val)
			player_count_val = 64
		}

		fmt.printf("Current player count: %d\n", player_count_val)

		// Get entity list pointer with error handling
		entity_list_ptr: win.DWORD
		if read_error := read(
			bp,
			uintptr(exe_base_addr) + ENTITY_LIST_OFFSET,
			&entity_list_ptr,
			size_of(entity_list_ptr),
		); !read_error {
			fmt.println("Failed to read entity list pointer")
			win.Sleep(1000)
			continue
		}

		if entity_list_ptr == 0 {
			fmt.println("Entity list pointer is null")
			win.Sleep(1000)
			continue
		}
		getNearestPlayer(bp, entity_list_ptr, player_count_val)
		if aimbot{
			aim_bot(bp)
		}
	}
}
RAD2DEG: f32 = 180.0 / math.PI
// Calculates pitch and yaw angles (in degrees) to aim from src towards dst
// Calculates pitch and yaw angles (in degrees) to aim from src towards dst
calc_angle :: proc(src: Vector3, dst: Vector3) -> Vector3 {
    fmt.println("src: ", src)
    fmt.println("dst: ", dst)
    
    // Calculate delta vector
    delta: Vector3
    delta.x = dst.x - src.x
    delta.y = dst.y - src.y
    delta.z = dst.z - src.z
    
    // Horizontal distance
    hyp := math.sqrt(delta.x * delta.x + delta.y * delta.y)
    
    // Calculate pitch and yaw
    pitch: f32 = 0.0
    yaw: f32 = 0.0
    
    // Handle pitch calculation - avoid division by zero
    if hyp > 0 {
        pitch = math.asin(delta.z / hyp) * RAD2DEG
    } else if delta.z > 0 {
        pitch = 90.0  // Looking straight up
    } else if delta.z < 0 {
        pitch = -90.0 // Looking straight down
    }
    
    // Calculate yaw (angle left/right) - normalize to 0-360 range
    yaw = math.atan2(delta.y, delta.x) * RAD2DEG
    
    // Normalize angles for game's coordinate system
    // Many games use different coordinate systems - this adjustment may be needed
    yaw = f32(int((yaw + 360.0)) % 360.0)
    
    return Vector3{pitch, yaw, 0.0}
}

aim_bot :: proc(bp: ^Bypass) {
    angle := calc_angle(local_player, closest_entity_info.position)
    fmt.println("aimbot angle: ", angle)
    newPitchAngle: f32 = 0
	newYawAngle: f32 = 0
	
    // Add game-specific angle correction if needed
    // Some engines expect different angle formats or coordinate systems
    // For example, if angles are reversed in the game:
    angle.y = f32(int((angle.y + 180.0)) % 360.0)  // This reverses the horizontal aim
    
    write(bp, uintptr(player_base) + uintptr(pitchAngleOffset), &angle.x, size_of(angle.x))
    write(bp, uintptr(player_base) + uintptr(yawAngleOffset), &angle.y, size_of(angle.y))
    fmt.printfln("x: %0.2f and y:%0.2f xx: %0.2f", angle.x, angle.y, angle.x)
}

getNearestPlayer :: proc(bp: ^Bypass, ptr: u32, player_count: u32) {
	players := make([dynamic]PlayerInfo, 0, player_count)
	defer delete(players)

	// Reset closest entity tracking
	closest_entity_distance = 999999.0
	closest_entity_index = -1

	// Process each player
	for i: u32 = 1; i < player_count; i += 1 {
		// Calculate entity address
		entity_ptr_addr := uintptr(ptr + (i * 4))
		// Read entity pointer
		entity_ptr: win.DWORD
		if read_error := read(bp, entity_ptr_addr, &entity_ptr, size_of(entity_ptr)); !read_error {
			fmt.printf("Warning: Failed to read entity pointer at index %d\n", i)
			continue
		}

		if entity_ptr == 0 {
			continue
		}
		/* 	// Skip local player (assuming it's at some index, adjust as needed)
		if entity_ptr == player_base {
			fmt.println("Skipping local player entity")
			continue
		} */
		// Initialize player info
		player: PlayerInfo
		// Read player username
		username_buffer: [32]u8
		if read_error := read(
			bp,
			uintptr(entity_ptr) + uintptr(0x205),
			&username_buffer,
			size_of(username_buffer),
		); !read_error {
			fmt.println("Failed to read player username")
			continue
		}
		// Ensure we have a proper string from the buffer
		username_len := 0
		for j := 0; j < len(username_buffer); j += 1 {
			if username_buffer[j] == 0 {
				username_len = j
				break
			}
		}
		if username_len == 0 {
			username_len = len(username_buffer)
		}
		player.username = strings.clone(string(username_buffer[:username_len]))
		// Read player position
		if read_error := read(
			bp,
			uintptr(entity_ptr) + uintptr(xPosOffset),
			&player.position.x,
			size_of(f32),
		); !read_error {
			fmt.println("Failed to read player X position")
			continue
		}
		if read_error := read(
			bp,
			uintptr(entity_ptr) + uintptr(yPosOffset),
			&player.position.y,
			size_of(f32),
		); !read_error {
			fmt.println("Failed to read player Y position")
			continue
		}
		if read_error := read(
			bp,
			uintptr(entity_ptr) + uintptr(zPosOffset),
			&player.position.z,
			size_of(f32),
		); !read_error {
			fmt.println("Failed to read player Z position")
			continue
		}
		// Calculate distance to local player
		player.distance = linalg.length(local_player - player.position)
		// Track closest entity
		if player.distance < closest_entity_distance {
			closest_entity_distance = player.distance
			closest_entity_index = i32(i)
			closest_entity_info = player
		}
		// Add player to our collection
		append(&players, player)
	}
	// Highlight closest entity
	if closest_entity_index >= 0 {
		fmt.println(
			"=============================================================================",
		)
		fmt.printf(
			"CLOSEST ENTITY: %s at %0.2f units away\n",
			closest_entity_info.username,
			closest_entity_distance,
		)
		fmt.println("entity 3d ", closest_entity_info.position)
		fmt.println(
			"=============================================================================",
		)
	}
	// Clean up strings
	for player in players {
		fmt.printfln("player hp: %v", player.health)
		box := Box{player.username,i32(player.position.x), i32(player.position.y),100, true}
		append(&boxlist, box)
		delete(player.username)
	}
	request_redraw()
	clear(&boxlist)
	win.Sleep(500) // Faster refresh rate for more responsive distance calculation
}

// Function to update local player position
update_local_player_position :: proc(bp: ^Bypass) {
	// Read local player position
	read(bp, uintptr(player_base) + uintptr(xPosOffset), &local_player.x, size_of(local_player.x))
	read(bp, uintptr(player_base) + uintptr(yPosOffset), &local_player.y, size_of(local_player.y))
	read(bp, uintptr(player_base) + uintptr(zPosOffset), &local_player.z, size_of(local_player.z))

	// Read local player angles
	read(
		bp,
		uintptr(player_base) + uintptr(pitchAngleOffset),
		&local_angles.pitch,
		size_of(local_angles.pitch),
	)
	read(
		bp,
		uintptr(player_base) + uintptr(yawAngleOffset),
		&local_angles.yaw,
		size_of(local_angles.yaw),
	)
}