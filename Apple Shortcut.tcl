# Apple Shortcut
#
# .types = ( com.apple.shortcut, shortcut );

include "Utility/General.tcl"

requires 0 "41454131"

set ::embedded_plist 1
include "hexfiend-templates/Apple Property List.tcl"

little_endian

main_guard {
    section "Header" {
        move 8
        set ::embedded_plist_size [uint32]
    }

    section "Embedded plist" {
        big_endian
        plist 12 $::embedded_plist_size
        little_endian
    }
}