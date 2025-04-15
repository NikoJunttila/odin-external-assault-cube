package external

import "core:fmt"
import win "core:sys/windows"
foreign import kernel "system:kernel32.lib"
foreign import psapi "system:psapi.lib"
import "core:c"
import "core:strings"
import "core:math"
import "core:time"


ENTITY_BASE :: 0x18AC00
ASSAULT_RIFLE_AMMO_OFFSET :: 0x140
HEALTH_OFFSET :: 0x00EC
EXE_NAME :: "ac_client.exe"
M_PI_2 :: 1.57079632679489661923 
base: win.DWORD


// Keyboard virtual keys
VK_W :: 0x57
VK_A :: 0x41
VK_S :: 0x53
VK_D :: 0x44
VK_END :: win.VK_END
VK_HOME :: win.VK_HOME
VK_ESCAPE :: win.VK_ESCAPE
VK_BACK :: win.VK_BACK

// Convert degrees to radians
deg_to_rad :: proc(degrees: f32) -> f32 {
    return degrees * (math.PI / 180.0)
}

main :: proc() {
    bp, exe_base_addr, ok := init_cheat()
    if (!ok){
        fmt.println("failed to init cheat")
        return
    }
    defer bypass_destroy(&bp)
    
    fmt.println("Press Home when loaded into a game to start cheat")
    for {
        if get_key_state(VK_HOME) {
            break
        }
        time.sleep(10 * time.Millisecond)
    }
    
    // Position and angle offsets
    xPosOffset := 0x2C
    yPosOffset := 0x28
    zPosOffset := 0x30
    pitchAngleOffset := 0x34
    yawAngleOffset := 0x38
    
    // Position and angle variables
    newXpos: f32 = 0
    newYpos: f32 = 0
    newZpos: f32 = 0
    newPitchAngle: f32 = 0
    newYawAngle: f32 = 0
    
    // Read initial position
    read(&bp, uintptr(base) + uintptr(xPosOffset), &newXpos, size_of(newXpos))
    read(&bp, uintptr(base) + uintptr(yPosOffset), &newYpos, size_of(newYpos))
    read(&bp, uintptr(base) + uintptr(zPosOffset), &newZpos, size_of(newZpos))
    
    fmt.println("Press END to pause the cheat")
    
    for !get_key_state(VK_END) {
        // Read current angles
        read(&bp, uintptr(base) + uintptr(pitchAngleOffset), &newPitchAngle, size_of(newPitchAngle))
        read(&bp, uintptr(base) + uintptr(yawAngleOffset), &newYawAngle, size_of(newYawAngle))
        
        tPI : f32= 2 * math.PI
        
        // Normalize angles
        if deg_to_rad(newPitchAngle) > tPI {
            newPitchAngle -= tPI
        } else if deg_to_rad(newPitchAngle) < 0 {
            newPitchAngle += tPI
        }
        
        if deg_to_rad(newYawAngle) > 1.57079632679489661923 - (1 / tPI) {
            newYawAngle -= math.PI - (1 / tPI)
        } else if deg_to_rad(newYawAngle) < - 1.57079632679489661923 + (1 / tPI) {
            newYawAngle += math.PI - (1 / tPI)
        }
        
        // Handle movement keys
        // FORWARD (W)
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
        
        // Write updated position
        write(&bp, uintptr(base) + uintptr(xPosOffset), &newXpos, size_of(newXpos))
        write(&bp, uintptr(base) + uintptr(yPosOffset), &newYpos, size_of(newYpos))
        write(&bp, uintptr(base) + uintptr(zPosOffset), &newZpos, size_of(newZpos))
        
		testVal : f32
    	read(&bp, uintptr(base) + uintptr(zPosOffset), &testVal, size_of(testVal))
		fmt.println(testVal)
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

// Helper function to check if a key is pressed
get_key_state :: proc(vk_code: c.int) -> bool {
    return (i32(win.GetAsyncKeyState(i32(vk_code))) & 0x8000) != 0
}