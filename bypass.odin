package external

import "core:fmt"
import win "core:sys/windows"

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

