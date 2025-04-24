package external

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:strings"
import "core:sync"
import win "core:sys/windows"
import "core:thread"
import "core:time"

player_base: win.DWORD 
EXE_NAME :: "ac_client.exe"

main :: proc() {
	bp, exe_base_addr, ok := init_cheat()
	if (!ok) {
		fmt.println("failed to init cheat")
		return
	}
	defer bypass_destroy(&bp)
	worker := thread.create_and_start(overlay)
	fmt.println("started overlay")
	time.sleep(1 * time.Second)
	entity_list_loop(&bp, exe_base_addr, false)
}
