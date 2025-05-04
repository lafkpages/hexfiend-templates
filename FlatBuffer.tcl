# FlatBuffer
#
# https://flatbuffers.dev/internals/#encoding-example
# application/vnd.apple.flatbuffer

include "Utility/General.tcl"

little_endian

main_guard {
    section "Header" {
        set table_offset [uint32]
        entry "Table offset" $table_offset 4 0
    }

    jumpa $table_offset {
        section "Table" {
            set vtable_offset [uint32]
            entry "VTable offset" $vtable_offset 4 $table_offset
        }
    }
}
