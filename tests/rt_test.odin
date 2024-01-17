package test

import "core:os"
import "core:fmt"
import "core:bytes"
import "core:strings"
import "core:testing"
import "core:compress/zlib"
import "core:path/filepath"

import cr "../src/reader"

// TODO: when we are able to extract zip files via the stdlib
//@test
test_rt_jar_files :: proc(t: ^testing.T) {
    java_home := os.get_env("JAVA_HOME", context.temp_allocator)
    if len(java_home) == 0 do return

    filename := strings.concatenate({java_home, "/lib/jrt-fs.jar"}, context.temp_allocator)
    data, ok := os.read_entire_file(filename)
    defer delete(data)
    if !ok do return // file may not be present there

    buf: bytes.Buffer
    defer bytes.buffer_destroy(&buf)
    err := zlib.inflate(data, &buf)
    if err != nil {
        testing.logf(t, "err: %v\n", err)
        testing.fail(t)
        return
    }

    testing.log(t, buf)
}

@test
test_arbitrary_classes :: proc(t: ^testing.T) {
    files_read := 0
    filepath.walk("res/java", visit_file, &files_read)
    testing.expect_value(t, files_read, 1313)
}

@private
visit_file :: proc(file: os.File_Info, in_err: os.Errno, user_data: rawptr) -> (err: os.Errno, skip_dir: bool) {
    if in_err != 0 do return

    data, ok := os.read_entire_file(file.fullpath) 
    defer delete(data)
    if !ok do return

    reader := cr.reader_new(data)
    classfile, cerr := cr.read_classfile(&reader)
    defer cr.classfile_destroy(classfile)
    classname := cr.classfile_get_class_name(classfile) 
    if cerr != .None {
        fmt.eprintf("error reading file %v: %v\n", classname, cerr)
    } else {
        files_read := cast(^int)user_data
        files_read^ += 1
    }

    return
}
