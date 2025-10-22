# Chrome Pak files (.pak)
#
# https://stackoverflow.com/a/13387521/15584743
#
# .types = ( pak );

include "Utility/General.tcl"
include "hexfiend-templates/helpers/util.tcl"

proc read_entry {} {
    set id [uint16 "Resource ID"]
    set offset [uint32 "Offset"]

    jumpa $offset {
        set length [uint32 "Length"]
        bytes $length "Data"
    }
}

main_guard {
    set version [uint32 "Version"]
    set num_entries [uint32 "Number of Entries"]

    uint8 "Encoding"

    for {set i 0} {$i < $num_entries} {incr i} {
        section -collapsed "Entry $i" {
            read_entry
        }
    }
}
