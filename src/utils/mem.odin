package utils

import "core:os"
import "core:fmt"
import "core:mem"
import "core:c/libc"
import "base:runtime"

import "lib:back"

@(private)
g_allocator: mem.Tracking_Allocator

@(require_results, deferred_none = tracking_allocator_report)
tracking_allocator_setup :: proc() -> runtime.Context {
    mem.tracking_allocator_init(&g_allocator, context.allocator)
    context.allocator = mem.tracking_allocator(&g_allocator)
    return context
}

@(private)
tracking_allocator_report :: proc() {
    defer mem.tracking_allocator_destroy(&g_allocator)

    if len(g_allocator.allocation_map) > 0 {
        fmt.eprintfln("=== %v allocations not freed: ===", len(g_allocator.allocation_map))
        for _, entry in g_allocator.allocation_map {
            fmt.eprintfln("- %v bytes @ %v", entry.size, entry.location)
        }
    }

    if len(g_allocator.bad_free_array) > 0 {
        fmt.eprintfln("=== incorrect frees: ===", len(g_allocator.bad_free_array))
        for entry in g_allocator.bad_free_array {
            fmt.eprintfln("- %p @ %v", entry.memory, entry.location)
        }
    }
}

// TODO: replace with back.register_sigill_handler

register_sigill_handler :: proc() {
    libc.signal(libc.SIGILL, proc "c" (code: i32) {
        context = runtime.default_context()
        context.allocator = context.temp_allocator

        trace := back.trace()
        lines, err := back.lines(trace.trace[:trace.len])
        if err != nil {
            fmt.eprintfln("Exception (Code %i)\nCould not get backtrace: %v", code, err)
        } else {
            fmt.eprintfln("Exception (Code %i)\n[back trace]", code)
            back.print(lines)
        }
        os.exit(int(code))
    })
}
