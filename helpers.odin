package external

import win "core:sys/windows"
import "core:c"
import "core:math"

/* LocalPlayer               [ac_client.exe + 0x0017E0A8]
Entity List               [ac_client.exe + 0x18AC04]
FOV                       [ac_client.exe + 0x18A7CC]
PlayerCount               [ac_client.exe + 0x18AC0C]

Position X                [0x2C]
Position Y                [0x30]
Position Z                [0x28]

Head Position X           [0x4]
Head Position Y           [0xC]
Head Position Z           [0x8]

Player Camera X           [0x34]
Player Camera Y           [0x38]

Assault Rifle Ammo        [0x140]
Submachine Gun Ammo       [0x138]
Sniper Ammo               [0x13C]
Shotgun                   [0x134]
Pistol Ammo               [0x12C]
Grenade Ammo              [0x144]

Fast fire Assault Rifle   [0x164]
Fast fire Sniper          [0x160]
Fast fire Shotgun         [0x158]

Auto shoot                [0x204]
Health Value              [0xEC]
Armor Value               [0xF0]
Player Name               [0x205] */

// Keyboard virtual keys
VK_W :: 0x57
VK_A :: 0x41
VK_S :: 0x53
VK_D :: 0x44
VK_END :: win.VK_END
VK_HOME :: win.VK_HOME
VK_ESCAPE :: win.VK_ESCAPE
VK_BACK :: win.VK_BACK

M_PI_2 :: 1.57079632679489661923 



// Convert degrees to radians
deg_to_rad :: proc(degrees: f32) -> f32 {
    return degrees * (math.PI / 180.0)
}
// Helper function to check if a key is pressed
get_key_state :: proc(vk_code: c.int) -> bool {
    return (i32(win.GetAsyncKeyState(i32(vk_code))) & 0x8000) != 0
}