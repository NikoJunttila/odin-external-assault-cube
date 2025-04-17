package external

import "core:c"
import "core:fmt"
import "core:math"
import "core:strings"
import win "core:sys/windows"
import "core:time"
import "core:log"

/* entity_list_loop :: proc(bp: ^Bypass, exe_base_addr : rawptr){
	player_count_val: win.DWORD
	read(
		bp,
		uintptr(exe_base_addr) + PLAYER_COUNT_OFFSET,
		&player_count_val,
		size_of(player_count_val),
	)
	fmt.println(player_count_val)
	entitylist: win.DWORD
	read(
		bp,
		uintptr(exe_base_addr) + uintptr(ENTITY_LIST_OFFSET),
		&entitylist,
		size_of(entitylist),
	)
	for{

		i: u32 = 0
		for i <= player_count_val {
			i += 1
			ent: win.DWORD
			read(bp, uintptr(entitylist + (i * 4)), &ent, size_of(ent))
			if ent == 0 {
				fmt.println("no ent")
				continue
			}
			user_name_buffer: [32]u8
			read(bp, uintptr(ent) + uintptr(0x205), &user_name_buffer, size_of(user_name_buffer))
			newXpos: f32 = 0
			newYpos: f32 = 0
			newZpos: f32 = 0
			// Read itial position
			read(bp, uintptr(player_base) + uintptr(xPosOffset), &newXpos, size_of(newXpos))
			read(bp, uintptr(player_base) + uintptr(yPosOffset), &newYpos, size_of(newYpos))
			read(bp, uintptr(player_base) + uintptr(zPosOffset), &newZpos, size_of(newZpos))
			fmt.println(
				"-----------------------------------------------------------------------------",
			)
			fmt.printfln("username %s: x:%0.2f, y:%0.2f, z:%0.2f", string(user_name_buffer[:]),newXpos,newYpos,newZpos)
		}
		win.Sleep(1000)
	}
}

 */


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
Vector3 :: struct {
    x, y, z: f32,
}

PlayerInfo :: struct {
    username: string,
    position: Vector3,
    health: f32,
    armor: f32,
    team: i32,
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

// Modified entity_list_loop to calculate distances from local player
entity_list_loop :: proc(bp: ^Bypass, exe_base_addr: rawptr) {
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

        // Store player information
        players := make([dynamic]PlayerInfo, 0, player_count_val)
        defer delete(players)
        
        // Reset closest entity tracking
        closest_entity_distance = 999999.0
        closest_entity_index = -1

        // Process each player
        for i: u32 = 1; i < player_count_val; i += 1 {
            // Calculate entity address
            entity_ptr_addr := uintptr(entity_list_ptr + (i * 4))
            
            // Read entity pointer
            entity_ptr: win.DWORD
            if read_error := read(bp, entity_ptr_addr, &entity_ptr, size_of(entity_ptr)); !read_error {
                fmt.printf("Warning: Failed to read entity pointer at index %d\n", i)
                continue
            }
            
            if entity_ptr == 0 {
                continue
            }
            
            // Skip local player (assuming it's at some index, adjust as needed)
            if entity_ptr == player_base {
                fmt.println("Skipping local player entity")
                continue
            }
            
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
            if read_error := read(bp, uintptr(entity_ptr) + uintptr(xPosOffset), &player.position.x, size_of(f32)); !read_error {
                fmt.println("Failed to read player X position")
                continue
            }
            
            if read_error := read(bp, uintptr(entity_ptr) + uintptr(yPosOffset), &player.position.y, size_of(f32)); !read_error {
                fmt.println("Failed to read player Y position")
                continue
            }
            
            if read_error := read(bp, uintptr(entity_ptr) + uintptr(zPosOffset), &player.position.z, size_of(f32)); !read_error {
                fmt.println("Failed to read player Z position")
                continue
            }
            
            // Calculate distance to local player
            player.distance = calculate_distance(local_player, player.position)
            
            // Track closest entity
            if player.distance < closest_entity_distance {
                closest_entity_distance = player.distance
                closest_entity_index = i32(i)
                closest_entity_info = player
            }
            
            // Add player to our collection
            append(&players, player)
            
            // Print player information including distance
            fmt.println("-----------------------------------------------------------------------------")
            fmt.printf("username %s: x:%0.2f, y:%0.2f, z:%0.2f | Distance: %0.2f units\n", 
                player.username, 
                player.position.x, 
                player.position.y, 
                player.position.z,
                player.distance)
        }

        // Highlight closest entity
        if closest_entity_index >= 0 {
            fmt.println("=============================================================================")
            fmt.printf("CLOSEST ENTITY: %s at %0.2f units away\n", 
                closest_entity_info.username, 
                closest_entity_distance)
            fmt.println("=============================================================================")
        }

        // Clean up strings
        for player in players {
            delete(player.username)
        }

        // Wait before next iteration
        win.Sleep(500) // Faster refresh rate for more responsive distance calculation
    }
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

// Utility function to calculate distance between two positions
calculate_distance :: proc(pos1, pos2: Vector3) -> f32 {
    dx := pos1.x - pos2.x
    dy := pos1.y - pos2.y
    dz := pos1.z - pos2.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
}