package main

import "core:os"
import "core:fmt"
import "core:mem"

main :: proc() {
    when ODIN_DEBUG {
        alloc: mem.Tracking_Allocator
        mem.tracking_allocator_init(&alloc, context.allocator)
        context.allocator = mem.tracking_allocator(&allow)

        defer {
            if len(alloc.allocation_map) > 0 {
                fmt.eprintf("=== %v allocations not freed: ===\n", len(alloc.allocation_map))
                for _, entry in alloc.allocation_map {
                    fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
                }
            }
            if len(alloc.bad_free_array) > 0 {
                fmt.eprintf("=== %v incorrect frees: ===\n", len(alloc.bad_free_array))
                for entry in alloc.bad_free_array {
                    fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
                }
            }
            mem.tracking_allocator_destroy(&alloc)
        }
    }

    args := os.args
    if len(args) < 2 {
        usage := fmt.aprintf("Usage: %s <input file>", args[0])
        defer delete(usage)
        fmt.println(usage)
        return
    }

    data, ok := os.read_entire_file_from_filename(args[1])
    defer delete(data)

    if !ok {
        fmt.println("Error reading file")
        return
    }

    reader := reader_new(data) 
    classfile, err := reader_read_class_file(&reader)
    defer classfile_destroy(&classfile)

    if err != .None {
        fmt.printf("Error parsing class file: %s\n", err)
        return
    }
    fmt.println("finished parsing class file")

    classfile_dump(&classfile)
}
