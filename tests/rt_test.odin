package test

import "core:os"
import "core:fmt"
import "core:log"
import "core:bytes"
import "core:strings"
import "core:testing"
import "core:compress/zlib"
import "core:path/filepath"

import cr "../src/reader"
import "../src/utils"

// TODO: when we are able to extract zip files via the stdlib
//@(test)
test_rt_jar_files :: proc(t: ^testing.T) {
    java_home := os.get_env("JAVA_HOME", context.temp_allocator)
    if len(java_home) == 0 do return

    filename := strings.concatenate({java_home, "/lib/jrt-fs.jar"}, context.temp_allocator)
    data, ok := os.read_entire_file(filename)
    if !ok do return // file may not be present there
    defer delete(data)

    buf: bytes.Buffer
    defer bytes.buffer_destroy(&buf)
    err := zlib.inflate(data, &buf)
    if err != nil {
        log.infof("err: %v\n", err)
        testing.fail(t)
        return
    }

    log.info(buf)
}

// TODO: what even is the version of these files?
@(test)
test_java_stdlib :: proc(t: ^testing.T) {
    utils.register_sigill_handler()
    files_read := 0
    filepath.walk("res/java", visit_file, &files_read)
    testing.expect_value(t, files_read, 1313)
}

@(private)
visit_file :: proc(file: os.File_Info, in_err: os.Error, user_data: rawptr) -> (err: os.Error, skip_dir: bool) {
    if in_err != nil do return

    data := os.read_entire_file(file.fullpath) or_return
    defer delete(data)

    reader := cr.reader_new(data)
    classfile, cerr := cr.read_classfile(&reader)
    defer cr.classfile_destroy(classfile)

    if cerr != .None {
        fmt.eprintfln("error reading file %v: %v", file.name, cerr)
        return
    }

    files_read := cast(^int)user_data
    files_read^ += 1

    return
}
