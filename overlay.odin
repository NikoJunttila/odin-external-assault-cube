package external

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:math"
import "core:strings"
import win "core:sys/windows"
import "core:time"

TRANSPARENCY_COLOR_KEY := win.COLORREF(win.RGB(0, 0, 0)) // Black
overlaywindow : win.HWND
DEFAULT_SQUARE_COLOR :: win.COLORREF(0x0000FF)
DEFAULT_TEXT_COLOR :: win.COLORREF(0x6F4FEF)

overlay :: proc() {
	// Get full screen dimensions
	screen_width := win.GetSystemMetrics(win.SM_CXSCREEN)
	screen_height := win.GetSystemMetrics(win.SM_CYSCREEN)
	fmt.printf("Screen dimensions: %d x %d\n", screen_width, screen_height)

	class_name := win.utf8_to_wstring("OdinTransparentClickThroughOverlay")
	title := win.utf8_to_wstring("") // Title is usually hidden for POPUP

	window_class: win.WNDCLASSEXW
	window_class.cbSize = size_of(win.WNDCLASSEXW)
	window_class.style = win.CS_HREDRAW | win.CS_VREDRAW // Redraw on resize
	window_class.lpfnWndProc = window_proc
	window_class.cbClsExtra = 0
	window_class.cbWndExtra = 0
	window_class.hInstance = win.HANDLE(win.GetModuleHandleW(nil))
	window_class.hIcon = nil // No icon needed for this type of window
	window_class.hIconSm = nil // No small icon needed
	window_class.hCursor = win.LoadCursorA(nil, win.IDC_ARROW) // Cursor might briefly show on creation/focus
	// Set background brush to the color key color.
	// Alternatively, set to nil and always clear manually in WM_PAINT.
	// Using GetStockObject(BLACK_BRUSH) is common if black is the key.
	window_class.hbrBackground = win.CreateSolidBrush(TRANSPARENCY_COLOR_KEY)
	// Ensure cleanup if we created the brush:
	if window_class.hbrBackground != nil {
		// Note: This defer might be tricky with application lifetime.
		// It's generally safer to destroy it explicitly before UnregisterClassW.
		// defer win.DeleteObject(window_class.hbrBackground) // Be careful with lifetime
	} else {
		// Fallback if brush creation failed (unlikely for solid color)
		window_class.hbrBackground = win.HBRUSH(win.GetStockObject(win.BLACK_BRUSH))
	}

	window_class.lpszMenuName = nil
	window_class.lpszClassName = class_name

	if atom := win.RegisterClassExW(&window_class); atom == 0 {
		last_error := win.GetLastError()
		fmt.eprintf("Failed to register window class. Error code: %d\n", last_error)
		return
	}

	// Create the window using the registered class name
	overlaywindow = win.CreateWindowExW(
		win.WS_EX_TOPMOST | win.WS_EX_LAYERED | win.WS_EX_TRANSPARENT, // --- Key Styles for Transparency + Click-Through ---// Keep window on top// Enable layered window support (required for SetLayeredWindowAttributes)// Make window transparent to mouse events (click-through)
		// ----------------------------------------------------
		class_name,
		title,
		win.WS_POPUP, // Borderless window style, suitable for overlays
		0, // Start at screen X = 0
		0, // Start at screen Y = 0
		screen_width, // Full screen width
		screen_height, // Full screen height
		nil, // No parent window
		nil, // No menu
		window_class.hInstance,
		nil, // No extra parameters
	)

	if overlaywindow == nil {
		last_error := win.GetLastError()
		fmt.eprintf("Failed to create window. Error code: %d\n", last_error)
		win.DeleteObject(win.HGDIOBJ(window_class.hbrBackground)) // Clean up created brush
		win.UnregisterClassW(class_name, window_class.hInstance) // Clean up class registration
		return
	}

	// --- Set the Transparency Key ---
	// Tell Windows that the color defined by TRANSPARENCY_COLOR_KEY should be transparent.
	if win.SetLayeredWindowAttributes(overlaywindow, TRANSPARENCY_COLOR_KEY, 0, 0x00000001) ==
	   false {
		last_error := win.GetLastError()
		fmt.eprintf("Failed to set layered window attributes. Error code: %d\n", last_error)
		// Handle error appropriately, maybe destroy window and exit
		win.DestroyWindow(overlaywindow) // Calls WM_DESTROY eventually
		// Need message loop briefly to process WM_DESTROY or PostQuitMessage won't be seen
		// This part is a bit awkward, better error handling strategy needed for robust apps
		// For now, just print and continue to exit path
	}
	// --------------------------------

	// Remove DwmExtendFrameIntoClientArea - it's not needed/useful with WS_EX_LAYERED+LWA_COLORKEY
	// margins := win.MARGINS{-1}
	// win.DwmExtendFrameIntoClientArea(overlaywindow, &margins)

	// Show the window
	win.ShowWindow(overlaywindow, win.SW_SHOW) // Use SW_SHOW or SW_SHOWDEFAULT
	win.UpdateWindow(overlaywindow) // Sends initial WM_PAINT
	fmt.println("Overlay window created. Running message loop...")
	// Message loop
	msg: win.MSG
	for win.GetMessageW(&msg, nil, 0, 0) > 0 {
		win.TranslateMessage(&msg)
		win.DispatchMessageW(&msg)
	}

	fmt.println("Exiting message loop.")

	// Clean up the created background brush if we made one
	if window_class.hbrBackground != nil {
		fmt.println("Deleting background brush.")
		win.DeleteObject(win.HGDIOBJ(window_class.hbrBackground))
	}

	// Unregister window class
	fmt.println("Unregistering window class.")
	if !win.UnregisterClassW(class_name, window_class.hInstance) {
		last_error := win.GetLastError()
		fmt.eprintf("Failed to unregister window class. Error code: %d\n", last_error)
	}

	fmt.println("Exiting.")
}
// Window Procedure
window_proc :: proc "stdcall" (
	hwnd: win.HWND,
	msg: u32,
	wparam: win.WPARAM,
	lparam: win.LPARAM,
) -> win.LRESULT {
	context = runtime.default_context()
	switch msg {
	case win.WM_PAINT:
		fmt.println("called WM_PAINT")
		ps: win.PAINTSTRUCT
		hdc := win.BeginPaint(hwnd, &ps)
		if hdc != nil {
			// --- Optional but recommended: Clear background with the color key ---
			// This ensures areas you don't explicitly draw on are transparent.
			// Get client rectangle dimensions
			client_rect: win.RECT
			win.GetClientRect(hwnd, &client_rect)
			// Create a brush with the color key (could also use the class background brush)
			bg_brush := win.CreateSolidBrush(TRANSPARENCY_COLOR_KEY)
			if bg_brush != nil {
				win.FillRect(hdc, &client_rect, bg_brush)
				win.DeleteObject(win.HGDIOBJ(bg_brush)) // Delete the temporary brush
			}
			// ----------------------------------------------------------------------

			// --- Call drawing function ---
			// Anything drawn here with a color *other than* the color key will be visible.
			// draw_overlay_content(hdc, hwnd)
			// draw_box("test", 100, 200)
			// ---------------------------

			win.EndPaint(hwnd, &ps)
		}
		return 0

	case win.WM_CLOSE:
		fmt.println("WM_CLOSE received")
		win.DestroyWindow(hwnd)
		return 0

	case win.WM_DESTROY:
		fmt.println("WM_DESTROY received")
		win.PostQuitMessage(0) // Signal main loop to exit
		return 0
	}

	return win.DefWindowProcW(hwnd, msg, wparam, lparam)
}


draw_box :: proc(
    name: string,
    x: i32,
    y: i32,
    size: i32 = 100,
    color: win.COLORREF = DEFAULT_SQUARE_COLOR,
    border_width: i32 = 2,
    text_color: win.COLORREF = DEFAULT_TEXT_COLOR,
    text_y_offset: i32 = 5,
) {
    // Get the device context
    if overlaywindow == nil {
        fmt.eprintf("Cannot draw box '%s': No window available\n", name)
        return
    }
    
    local_hdc := win.GetDC(overlaywindow)
    if local_hdc == nil {
        fmt.eprintf("Failed to get device context for square '%s'\n", name)
        return
    }
    defer win.ReleaseDC(overlaywindow, local_hdc)
    
    // --- Draw the Square Outline ---
    pen := win.CreatePen(win.PS_SOLID, border_width, color)
    if pen == nil {
        fmt.eprintf("Failed to create pen for square '%s'\n", name)
        return
    }
    defer win.DeleteObject(win.HGDIOBJ(pen))

    old_pen := win.SelectObject(local_hdc, win.HGDIOBJ(pen))
    if old_pen == nil {
        fmt.eprintf("Failed to select pen into DC for square '%s'\n", name)
        return
    }
    defer win.SelectObject(local_hdc, old_pen)

    // Rest of your drawing code, but use local_hdc instead of hdc
    null_brush := win.GetStockObject(win.NULL_BRUSH)
    old_brush := win.SelectObject(local_hdc, null_brush)
    defer win.SelectObject(local_hdc, old_brush)

    right := x + size
    bottom := y + size

    if !win.Rectangle(local_hdc, x, y, right, bottom) {
        fmt.eprintf("Failed to draw rectangle for square '%s'\n", name)
    }

    if len(name) > 0 {
        name_wstr := win.utf8_to_wstring(name)
        old_text_color := win.SetTextColor(local_hdc, text_color)
        defer win.SetTextColor(local_hdc, old_text_color)
        old_bk_mode := win.SetBkMode(local_hdc, win.BKMODE.TRANSPARENT)

        text_x := x
        text_y := bottom + text_y_offset
        if !win.TextOutW(local_hdc, text_x, text_y, name_wstr, i32(len(name))) {
            fmt.eprintf("Failed to draw text for square '%s'\n", name)
        }
    }
	// win.InvalidateRect(overlaywindow, nil, false)
}

// Renamed drawing function for clarity
draw_overlay_content :: proc(hdc: win.HDC, hwnd: win.HWND) {

	client_rect: win.RECT
	if !win.GetClientRect(hwnd, &client_rect) {
		// Handle error if we can't get the client rect
		fmt.eprintln("Failed to get client rect")
		return
	}
	screen_width := client_rect.right - client_rect.left // right usually holds width as left is 0
	screen_height := client_rect.bottom - client_rect.top

	// --- Define the *size* of the box ---
	box_width: i32 = 200
	box_height: i32 = 150

	// --- Calculate coordinates for centered box ---
	center_x := screen_width / 2
	center_y := screen_height / 2

	box_left := center_x - (box_width / 2)
	box_top := center_y - (box_height / 2)
	box_right := box_left + box_width // or center_x + (box_width / 2)
	box_bottom := box_top + box_height // or center_y + (box_height / 2)

	box_color := win.RGB(255, 0, 0) // Red color
	box_border_width: i32 = 3

	pen := win.CreatePen(win.PS_SOLID, box_border_width, box_color)
	if pen == nil {
		fmt.eprintln("Failed to create pen")
		return
	}
	defer win.DeleteObject(win.HGDIOBJ(pen)) // Use HGDIOBJ cast for DeleteObject

	old_pen := win.SelectObject(hdc, win.HGDIOBJ(pen)) // Use HGDIOBJ cast for SelectObject
	if old_pen == nil {
		fmt.eprintln("Failed to select pen into DC")
		return
	}
	defer win.SelectObject(hdc, old_pen) // Restore old pen

	// Use a NULL_BRUSH to prevent Rectangle from filling the inside
	// Alternatively, keep using SetBkMode(TRANSPARENT)
	null_brush := win.GetStockObject(win.NULL_BRUSH)
	old_brush := win.SelectObject(hdc, null_brush)
	defer win.SelectObject(hdc, old_brush)

	// Draw the rectangle outline
	win.Rectangle(hdc, box_left, box_top, box_right, box_bottom)


	// --- Example: Draw some text ---
	// This text will be visible because Cyan is not the TRANSPARENCY_COLOR_KEY (black)
	text := "Click-Through Overlay! (Odin + Win32)"
	text_wstr := win.utf8_to_wstring(text)
	text_color := win.RGB(0, 255, 255) // Cyan text
	old_text_color := win.SetTextColor(hdc, text_color)
	defer win.SetTextColor(hdc, old_text_color)

	// Set background mode to transparent for text drawing so the color key doesn't show behind letters
	old_bk_mode := win.SetBkMode(hdc, win.BKMODE.TRANSPARENT) // Use enum member directly
	// defer win.SetBkMode(hdc, old_bk_mode)             // Restore original background mode

	// Draw text below the box
	win.TextOutW(hdc, box_left, box_bottom + 10, text_wstr, i32(len(text))) // Use len(text_wstr) for UTF-16 length


	// --- Draw something using the transparency color key (example) ---
	// This rectangle *should* be invisible because it uses the color key
	invisible_box_left := box_right + 20
	invisible_pen := win.CreatePen(win.PS_SOLID, 1, TRANSPARENCY_COLOR_KEY)
	if invisible_pen != nil {
		defer win.DeleteObject(win.HGDIOBJ(invisible_pen))
		old_invisible_pen := win.SelectObject(hdc, win.HGDIOBJ(invisible_pen))
		if old_invisible_pen != nil {
			// Need to select a fill brush of the same color too for FillRect
			invisible_brush := win.CreateSolidBrush(TRANSPARENCY_COLOR_KEY)
			if invisible_brush != nil {
				defer win.DeleteObject(win.HGDIOBJ(invisible_brush))
				old_invisible_brush := win.SelectObject(hdc, win.HGDIOBJ(invisible_brush))
				// Draw filled rectangle
				win.Rectangle(
					hdc,
					invisible_box_left,
					box_top,
					invisible_box_left + 50,
					box_bottom,
				)
				win.SelectObject(hdc, old_invisible_brush) // Restore brush
			}
			win.SelectObject(hdc, old_invisible_pen) // Restore pen
		}
	}
	// Note: The invisible box outline might still show slightly due to anti-aliasing if enabled system-wide.
}