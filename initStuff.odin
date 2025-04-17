package external

import "core:fmt"
import win "core:sys/windows"
foreign import psapi "system:psapi.lib"
import "core:c"
import "core:strings"

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
			fmt.printfln("Found process: %s with base addr: %v", mod_name, hMods[i])
			return hMods[i], true
		}
	}
	return nil, false
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

init_cheat :: proc() -> (Bypass, rawptr, bool) {
	bp := bypass_init()
	pid, ok := find_pid(EXE_NAME)
	if (!ok) {
		fmt.println("error getting pid", win.GetLastError())
		return bp, nil, false
	}
	if !attach(&bp, pid) {
		fmt.println("failed attach")
		return bp, nil, false
	}
	exe_base_addr, ok2 := get_base_addr(&bp, EXE_NAME) //should be 0x400000
	if !ok2 {
		fmt.println("error getting base addr")
		return bp, nil, false
	}
	//finding player entity base value address
	read(&bp, uintptr(exe_base_addr) + ENTITY_BASE_OFFSET, &player_base, size_of(player_base))
	return bp, exe_base_addr, true
}
