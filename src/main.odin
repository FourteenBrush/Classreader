package classreader

import "core:fmt"
import "core:os"
import win32 "core:sys/windows"

import "reader"
import "utils"

_ :: win32

main :: proc() {
	when ODIN_DEBUG {
		utils.tracking_allocator_setup()
		utils.register_sigill_handler()
	}

	if len(os.args) < 2 {
		fmt.printfln("Usage: %s <input file>", os.args[0])
		os.exit(1)
	}

	data, ok := os.read_entire_file(os.args[1])
	defer delete(data)

	if !ok {
		fmt.eprintln("Error reading file, os error", get_last_error())
		os.exit(2)
	}

	creader := reader.reader_new(data)
	classfile, err := reader.read_classfile(&creader)
	defer reader.classfile_destroy(classfile)

	if err != .None {
		fmt.eprintln("Error parsing class file:", err)
		os.exit(3)
	}

	reader.classfile_dump(classfile)
}

@(private)
get_last_error :: proc() -> int {
	return int(win32.GetLastError()) when ODIN_OS == .Windows else os.get_last_error()
}
