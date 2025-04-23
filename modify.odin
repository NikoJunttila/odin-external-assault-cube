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

player_base: win.DWORD // Assuming these are for later use
EXE_NAME :: "ac_client.exe" // Assuming these are for later use

main :: proc() {
	bp, exe_base_addr, ok := init_cheat()
	if (!ok) {
		fmt.println("failed to init cheat")
		return
	}
	defer bypass_destroy(&bp)
	// entity_list_loop(&bp, exe_base_addr, false)
	worker := thread.create_and_start(overlay)
	fmt.println("started overlay")
	time.sleep(1 * time.Second)
	for {
		random := rand.int_max(11) + 2
		y := random * 100
		x := y - 200
		fmt.printfln("new box %v %v ", x, y)
		draw_box("tester main", i32(x), i32(y))
		time.sleep(1 * time.Second)
	}
}
