package external

import "core:c"
import "core:fmt"
import "core:math"
import "core:strings"
import win "core:sys/windows"
import "core:time"
//player entity.
ENTITY_BASE_OFFSET :: 0x18AC00
ENTITY_LIST_OFFSET :: 0x18AC04
PLAYER_COUNT_OFFSET :: 0x18AC0C
xPosOffset :: 0x2C
yPosOffset :: 0x28
zPosOffset :: 0x30
pitchAngleOffset :: 0x34
yawAngleOffset :: 0x38

ASSAULT_RIFLE_AMMO_OFFSET :: 0x140
HEALTH_OFFSET :: 0x00EC
EXE_NAME :: "ac_client.exe"

player_base: win.DWORD

main :: proc() {
	bp, exe_base_addr, ok := init_cheat()
	if (!ok) {
		fmt.println("failed to init cheat")
		return
	}
	defer bypass_destroy(&bp)
	entity_list_loop(&bp, exe_base_addr)
}
EntityList :: struct {
	players: ^ACPlayer,
}
