package classreader

import "core:os"
import "core:fmt"
import "core:mem"
import "core:c/libc"
import "core:runtime"
@require // suppress unused package error on non windows targets
import win32 "core:sys/windows"

import "reader"
import "../dependencies/back"

main :: proc() {
    when ODIN_DEBUG {
        alloc: mem.Tracking_Allocator
        mem.tracking_allocator_init(&alloc, context.allocator)
        context.allocator = mem.tracking_allocator(&alloc)

        defer {
            if len(alloc.allocation_map) > 0 {
                fmt.eprintfln("=== %v allocations not freed: ===", len(alloc.allocation_map))
                for _, entry in alloc.allocation_map {
                    fmt.eprintfln("- %v bytes @ %v", entry.size, entry.location)
                }
            }
            if len(alloc.bad_free_array) > 0 {
                fmt.eprintfln("=== %v incorrect frees: ===", len(alloc.bad_free_array))
                for entry in alloc.bad_free_array {
                    fmt.eprintf("- %p @ %v", entry.memory, entry.location)
                }
            }
            mem.tracking_allocator_destroy(&alloc)
        }

        register_sigill_handler()
    }

    args := os.args
    if len(args) < 2 {
        fmt.printfln("Usage: %s <input file>", args[0])
        os.exit(1)
    }

    data, ok := os.read_entire_file(args[1])
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

register_sigill_handler :: proc() {
    libc.signal(libc.SIGILL, proc "c" (code: i32) {
        context = runtime.default_context()
        context.allocator = context.temp_allocator

        backtrace: {
            t := back.trace()
            lines, err := back.lines(t.trace[:t.len])
            if err != nil {
                fmt.eprintfln("Exception (Code %i)\nCould not get backtrace: %v", code, err)
                break backtrace
            }

            fmt.eprintfln("Exception (Code %i)\n[back trace]", code)
            back.print(lines)
        }
        os.exit(int(code))
    }) 
}


get_last_error :: proc() -> int {
    return int(win32.GetLastError()) when ODIN_OS == .Windows else os.get_last_error()
}
