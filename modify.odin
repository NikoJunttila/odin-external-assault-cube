package external

import "core:fmt"
import win "core:sys/windows"
foreign import kernel "system:kernel32.lib"
foreign import psapi "system:psapi.lib"
import "core:c"
import "core:strings"


ENTITY_BASE :: 0x18AC00
ASSAULT_RIFLE_AMMO_OFFSET :: 0x140
HEALTH_OFFSET :: 0x00EC

// Windows API types and constants
MODULEINFO :: struct {
	lpBaseOfDll: rawptr,
	SizeOfImage: c.uint,
	EntryPoint:  rawptr,
}

@(default_calling_convention = "c")
foreign psapi {
	@(link_name = "GetModuleInformation")
	get_module_information :: proc(process: win.HANDLE, module: win.HMODULE, module_info: ^MODULEINFO, size: win.DWORD) -> win.BOOL ---

	@(link_name = "GetProcessImageFileNameW")
	get_process_image_file_name :: proc(process: win.HANDLE, name: win.LPWSTR, size: win.DWORD) -> win.DWORD ---

	@(link_name = "EnumProcessModules")
	enum_process_modules :: proc(hProcess: win.HANDLE, lphModule: ^win.HMODULE, cb: win.DWORD, lpcbNeeded: ^win.DWORD) -> win.BOOL ---

	@(link_name = "GetModuleFileNameExW")
	get_module_file_name :: proc(hProcess: win.HANDLE, hModule: win.HMODULE, lpFilename: win.LPWSTR, nSize: win.DWORD) -> win.DWORD ---
}

get_base_addr :: proc(bp: ^Bypass, process_name: string) -> (win.HMODULE, bool) {
	hMods: [1024]win.HMODULE
	cbNeeded: win.DWORD

	ok := enum_process_modules(bp.m_hProcess, &hMods[0], size_of(hMods), &cbNeeded)
	if (!ok) {
		fmt.println("enum failed: ", win.GetLastError())
		return nil, false
	}
	for i := 0; i < int(cbNeeded / size_of(win.HMODULE)); i += 1 {
		mod_name_buf: [win.MAX_PATH]u16
		check := get_module_file_name(
			bp.m_hProcess,
			hMods[i],
			&mod_name_buf[0],
			win.DWORD(len(mod_name_buf)),
		)
		mod_name, _ := win.utf16_to_utf8(mod_name_buf[:])
		if strings.contains(strings.to_lower(mod_name), strings.to_lower(process_name)) {
			fmt.printfln("%s", mod_name)
			fmt.println(hMods[i])
			return hMods[i], true
		}
	}
	return nil, false
}

Bypass :: struct {
	m_hProcess: win.HANDLE,
}

// Constructor equivalent - initialize the struct
bypass_init :: proc() -> Bypass {
	return Bypass{m_hProcess = nil}
}

// Destructor equivalent - cleanup resources
bypass_destroy :: proc(bp: ^Bypass) {
	if bp.m_hProcess != nil {
		win.CloseHandle(bp.m_hProcess)
	}
}

// Attach to a process by PID
attach :: proc(bp: ^Bypass, pid: win.DWORD) -> bool {
	//back up win.PROCESS_ALL_ACCESS
	required_access: u32 =
		win.PROCESS_VM_READ |
		win.PROCESS_VM_WRITE |
		win.PROCESS_VM_OPERATION |
		win.PROCESS_QUERY_INFORMATION
	bp.m_hProcess = win.OpenProcess(required_access, false, pid)
	if (bp.m_hProcess == nil) {
		fmt.println("error attach: ", win.GetLastError())
	}
	return bp.m_hProcess != nil
}

// Read memory from the attached process
read :: proc(
	bp: ^Bypass,
	lpBaseAddress: uintptr,
	lpBuffer: rawptr,
	nSize: win.SIZE_T,
	lpNumberOfBytesRead: ^win.SIZE_T = nil,
) -> bool {
	return bool(
		win.ReadProcessMemory(
			bp.m_hProcess,
			win.LPCVOID(lpBaseAddress),
			lpBuffer,
			nSize,
			lpNumberOfBytesRead,
		),
	)
}

// Write memory to the attached process
write :: proc(
	bp: ^Bypass,
	lpBaseAddress: uintptr,
	lpBuffer: rawptr,
	nSize: win.SIZE_T,
	lpNumberOfBytesWritten: ^win.SIZE_T = nil,
) -> bool {
	return bool(
		win.WriteProcessMemory(
			bp.m_hProcess,
			win.LPVOID(lpBaseAddress),
			lpBuffer,
			nSize,
			lpNumberOfBytesWritten,
		),
	)
}

main :: proc() {
	procName := "ac_client.exe"
	pid, ok := find_pid(procName)
	if (!ok) {
		fmt.println("error getting pid", win.GetLastError())
		return
	}

	bp := bypass_init()
	defer bypass_destroy(&bp)

	if !attach(&bp, pid) {
		fmt.println("failed attach")
		return
	}

	exe_base_addr, ok2 := get_base_addr(&bp, procName) //should be 0x400000
	if !ok2 {
		fmt.println("error getting base addr")
		return
	}
	// base from where we add offset
	base: win.DWORD
	read(&bp, uintptr(exe_base_addr) + ENTITY_BASE, &base, size_of(base))
	fmt.println(base)

	example_read_val : u32 = 0
	// Reading from target process
	if read(&bp, uintptr(base) + HEALTH_OFFSET, &example_read_val, size_of(example_read_val)) {
		fmt.printfln("Successfully read value:%v", example_read_val)
	} else {
		fmt.println("Failed to read from target process.")
	}

	cfg := default_config()
	cfg.update_interval_ms = 10
	for {
		win.Sleep(cfg.update_interval_ms)
		if write(
			&bp,
			uintptr(base) + ASSAULT_RIFLE_AMMO_OFFSET,
			&cfg.target_ammo,
			size_of(cfg.target_ammo),
		) {
			fmt.println("Successfully wrote value ammo:", cfg.target_ammo)
		} else {
			fmt.println("Failed to write to target process.")
		}
		if write(
			&bp,
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

find_pid :: proc(pName: string) -> (u32, bool) {
	pid: u32

	handle := win.CreateToolhelp32Snapshot(win.TH32CS_SNAPPROCESS, 0)

	if handle == win.INVALID_HANDLE_VALUE || handle == nil {
		fmt.println("handle invalid")
		return pid, false
	}
	defer win.CloseHandle(handle)
	proc_entry: win.PROCESSENTRY32W
	proc_entry.dwSize = size_of(proc_entry)

	if (win.Process32FirstW(handle, &proc_entry)) {
		for (win.Process32NextW(handle, &proc_entry)) {
			current_name, _ := win.utf16_to_utf8(proc_entry.szExeFile[:])
			// fmt.println(current_name)
			if current_name == pName {
				pid = proc_entry.th32ProcessID
				return pid, true
			}
		}
	}
	return pid, false
}

Config :: struct {
	target_health:      i32,
	target_ammo:        i32,
	update_interval_ms: u32,
}

default_config :: proc() -> Config {
	return Config{target_health = 100, target_ammo = 20, update_interval_ms = 1000}
}

// POINT3D equivalent in Odin
Point3D :: struct {
	x: f32,
	y: f32,
	z: f32,
}

// ACPLAYER struct converted to Odin
ACPlayer :: struct {
	unknown1:                 [4]byte, // +0x0
	headPosition:             Point3D, // +0x4
	unknown2:                 [0x24]byte, // +0x10
	position:                 Point3D, // +0x34
	view:                     Point3D, // +0x40
	unknown3:                 [8]byte, // +0x58
	jumpFallSpeed:            i32, // +0x54
	noClip:                   f32, // +0x58
	unknown4:                 [0x14]byte, // +0x5C
	isImmobile:               i32, // +0x70
	unknown5:                 [0xE]byte, // +0x74
	state:                    i8, // +0x82
	unknown6:                 [0x75]byte, // +0x83
	hp:                       i32, // +0xF8
	armor:                    i32, // +0xFC
	unknown7:                 [0xC]byte, // +0x100
	dualPistolEnabled:        i8, // +0x10C
	unknown8:                 [0x7]byte, // +0x10D
	pistolReserveAmmos:       i32, // +0x114
	carabineReserveAmmos:     i32, // +0x118
	shotgunReserveAmmos:      i32, // +0x11C
	smgReserveAmmos:          i32, // +0x120
	sniperRifleReserveAmmos:  i32, // +0x124
	assaultRifleReserveAmmos: i32, // +0x128
	unknown9:                 [0x8]byte, // +0x12C
	doublePistolReserveAmmos: i32, // +0x134
	unknown10:                [0x4]byte, // +0x138
	pistolLoadedAmmos:        i32, // +0x13C
	carabineLoadedAmmos:      i32, // +0x140
	shotgunLoadedAmmos:       i32, // +0x144
	smgLoadedAmmos:           i32, // +0x148
	sniperRifleLoadedAmmos:   i32, // +0x14C
	assaultRifleLoadedAmmos:  i32, // +0x150
	unknown11:                [0x4]byte, // +0x154
	grenades:                 i32, // +0x158
	doublePistolLoadedAmmos:  i32, // +0x15C
	knifeSlashDelay:          i32, // +0x160
	pistolShootDelay:         i32, // +0x164
	carabineShootDelay:       i32, // +0x168
	shotgunShootDelay:        i32, // +0x16C
	smgShootDelay:            i32, // +0x170
	sniperRifleShootDelay:    i32, // +0x174
	assaultRifleShootDelay:   i32, // +0x178
	unknown12:                [0x8]byte, // +0x17C
	doublePistolShootDelay:   i32, // +0x184
	unknown13:                [0x7C]byte, // +0x188
	numberOfDeaths:           i32, // +0x204
	unknown14:                [0x1D]byte, // +0x208
	nickname:                 [16]byte, // +0x225 (CHAR converted to byte array)
	unknown15:                [0xF7]byte, // +0x235
	team:                     i8, // +0x32C
}
