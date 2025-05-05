include "Utility/General.tcl"
include "hexfiend-templates/helpers/util.tcl"

# Seen in NSOSPLastRootDirectory property in many Apple plist files
# https://github.com/p0deje/Maccy/issues/883
# https://github.com/p0deje/Maccy/issues/901
# https://github.com/p0deje/Maccy/issues/991
# https://discussions.apple.com/thread/255893588?answerId=261025429022
# https://www.reddit.com/r/Chitubox/comments/1k2x8zv/comment/mo33qvi
# https://bjjii.com/540/

requires 0 "626F6F6B"

proc part {} {
    section -collapsed "Unknown part" {
        set size [uint32]
        move -4
        entry "Size" $size 4
        move 4

        set type [uint32]
        switch $type {
            257 {
                sectionname "String"
            }
            4294967294 {
                sectionname "EOF"
            }
            default {
                sectionname "Part type $type"
            }
        }
        move -4
        entry "Type" $type 4
        move 4

        if { $size } {
            set str_value [ascii $size]

            sectionvalue $str_value
            move -$size
            entry "Value" $str_value $size
            move $size
        } else {
            set str_value ""
        }

        set padding [expr {(4 - ($size % 4)) % 4}]
        if { $padding } {
            entry "Padding" "" $padding
            move $padding
        }
    }
}

main_guard {
    section -collapsed "Header" {
        ascii 4 "Header"

        set len [uint32]
        move -4
        entry "File length" $len 4
        move 4
        assert { $len == [len] }

        set padding 56
        entry "Padding" "" $padding
        move $padding
    }

    while {![end]} {
        part
    }
}
