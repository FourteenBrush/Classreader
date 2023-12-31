package validation_test

import "core:testing"
// TODO: fix import paths, this looks scuffed
import validate "../src"

expect :: testing.expect
expect_value :: testing.expect_value

FIELD_DESCRIPTOR_CASES := []struct { desc: string, valid: bool } {
    { "Ljava/lang/Object;", true },
    { "[[[D", true },
    { "[Ljava/lang/Object;", true },
    { "LL/test/something/I;", true },
    { "Ljava/lang.String;", false },
}

@test
test_field_descriptors :: proc(t: ^testing.T) {
    for entry in FIELD_DESCRIPTOR_CASES {
        result := validate.validate_field_descriptor(entry.desc)
        if result != entry.valid {
            testing.logf(t, "expected %s to be %s field descriptor\n", entry.desc, "a valid" if entry.valid else "an invalid")
            testing.fail(t)
        }
    }
}
