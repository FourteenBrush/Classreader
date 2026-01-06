package classreader

import "core:fmt"
import "core:os"

import "reader"
import "utils"

_ :: utils

main :: proc() {
    when ODIN_DEBUG {
        context = utils.tracking_allocator_setup()
        utils.register_sigill_handler()
    }

    if len(os.args) < 2 {
        fmt.printfln("Usage: %s <input file>", os.args[0])
        os.exit(1)
    }

    fd, err := os.open(os.args[1])
    if err != nil {
        fmt.eprintln(os.error_string(err))
        os.exit(1)
    }

    if !os.is_file(fd) {
        fmt.eprintfln("File %s is not a normal file", os.args[1])
        os.exit(1)
    }

    data, ok := os.read_entire_file(fd)
    if !ok {
        err := os.get_last_error()
        fmt.eprintln("Error reading file,", os.error_string(err))
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
