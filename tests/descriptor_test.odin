package test

import "core:log"
import "core:testing"
import "../src/reader"

FIELD_DESCRIPTOR_CASES := []struct { desc: string, valid: bool } {
    { "Ljava/lang/Object;", true },
    { "[[[D", true },
    { "[Ljava/lang/Object;", true },
    { "LL/test/something/I;", true },
    { "Ljava/lang.String;", false },
    { "I", true },
    { "C", true },
    { "Z", true },
    { "[I", true },
    { "[[F", true },
    { "[[C", true },
    { "Ljava/util/List;", true },
    { "Ljava/util/List<java/lang/String>;", false },
    { "[[Ljava/lang/String;", true },
    { "Ljava/lang/String[][]", false },
    { "Ljava/lang/String[]", false },
    { "Ljava/nio/ByteBuffer;", true },
    { "[[B", true },
    { "Ljava/time/LocalDate;", true },
    { "Lsomethingé/Exotic;", true },
    { "L;", false },
    { "[", false },
    { "[[", false },
    { "L[;", false },
    { "", false },
    { "L/;", false },
    { "L/", false },
    { "L/a;", false },
}

@test
test_field_descriptors :: proc(t: ^testing.T) {
    for entry in FIELD_DESCRIPTOR_CASES {
        result := reader.is_valid_field_descriptor(entry.desc)
        if result != entry.valid {
            log.infof("expected %s to be %s field descriptor\n", entry.desc, "a valid" if entry.valid else "an invalid")
            testing.fail(t)
        }
    }
}
