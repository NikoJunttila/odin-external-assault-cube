package external

import "core:fmt"
import win "core:sys/windows"
import "core:c"
import "core:strings"

inf_hp_ammo_loop :: proc(bp : ^Bypass, cfg : ^Config){
	for {
		win.Sleep(cfg.update_interval_ms)
		if write(
			bp,
			uintptr(base) + ASSAULT_RIFLE_AMMO_OFFSET,
			&cfg.target_ammo,
			size_of(cfg.target_ammo),
		) {
			fmt.println("Successfully wrote value ammo:", cfg.target_ammo)
		} else {
			fmt.println("Failed to write to target process.")
		}
		if write(
			bp,
			uintptr(base) + HEALTH_OFFSET,
			&cfg.target_health,
			size_of(cfg.target_health),
		) {
			fmt.println("Successfully wrote value hp:", cfg.target_health)
		} else {
			fmt.println("Failed to write to target process.")
		}
	}
}