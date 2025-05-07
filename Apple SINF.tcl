# SINF
#
# iOS apps
#
# .types = ( sinf );

include "Utility/General.tcl"

big_endian

requires 4 "73696E66"

main_guard {
    section "Header" {
        set _len [uint32]
        move -4
        entry "File size" $_len 4
        move 4
        assert { $_len == [len] }

        ascii 4 "Magic bytes"
    }
}
