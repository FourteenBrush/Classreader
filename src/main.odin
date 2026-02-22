package classreader

import "core:os"
import "core:fmt"
import "core:path/filepath"

import "reader"

@(require) import "lib:back"

main :: proc() {
    when ODIN_DEBUG {
        tracking_alloc: back.Tracking_Allocator
        back.tracking_allocator_init(&tracking_alloc, context.allocator)
        context.allocator = back.tracking_allocator(&tracking_alloc)

        defer back.tracking_allocator_print_results(&tracking_alloc, .Both)
        back.register_segfault_handler()
    }

    if len(os.args) < 2 {
        fmt.printfln("Usage: %s <input file>", filepath.base(os.args[0]))
        os.exit(1)
    }

    file, oerr := os.open(os.args[1])
    if oerr != nil {
        fmt.eprintln(os.error_string(oerr))
        os.exit(1)
    }

    if !os.is_file(os.name(file)) {
        fmt.eprintfln("File %s is not a normal file", os.args[1])
        os.exit(1)
    }

    data, rerr := os.read_entire_file(file, context.allocator)
    if rerr != nil {
        fmt.eprintln("Error reading file,", os.error_string(rerr))
        os.exit(1)
    }
    defer delete(data)

    creader := reader.reader_new(data)
    classfile, cerr := reader.read_classfile(&creader)
    defer reader.classfile_destroy(classfile)

    if cerr != .None {
        fmt.eprintln("Error parsing class file:", cerr)
        os.exit(1)
    }

    reader.classfile_dump(classfile)
}
