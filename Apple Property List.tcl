# Apple Property List
#
# https://en.wikipedia.org/wiki/Property_list
#
# .types = ( com.apple.property-list, plist );

include "Utility/General.tcl"

requires 0 "62706C697374"

big_endian

variable offset_table_offset_size
variable object_ref_size
variable num_objects
variable top_object_offset
variable offset_table_start

set objectTable [list]

proc uint_n {n} {
    # Otherwise, throw

    switch $n {
        1 { return [uint8] }
        2 { return [uint16] }
        4 { return [uint32] }
        8 { return [uint64] }
        default {
            die "Invalid uint_n size: $n"
        }
    }
}

proc parseInt {{ markerRightValue "" }} {
    if { $markerRightValue == "" } {
        set markerRightValue [expr { [uint8] & 15 }]
    }

    set intSize [expr { 2 ** $markerRightValue }]
    set intValue [uint_n $intSize]

    return [list $intValue $intSize]
}

proc parseObject {} {
    section -collapsed "Unknown object"

    set markerByteValue [uint8]
    move -1
    binary scan [bytes 1] Bu8 markerByte

    set markerLeft [string range $markerByte 0 3]
    set markerRight [string range $markerByte 4 7]

    move -1
    entry "Object Marker" $markerByte 1
    move 1

    set markerRightValue [expr { $markerByteValue & 15 }]

    switch $markerLeft {
        0001 {
            sectionname "Int"

            set int [parseInt $markerRightValue]
            set intValue [lindex $int 0]
            set intSize [lindex $int 1]

            move -$intSize
            move -1
            entry "Int size" $intSize 1
            move 1

            sectionvalue $intValue
            entry "Int value" $intValue $intSize
            move $intSize

            endsection
            return [list $markerLeft $intValue $intSize]
        }

        0011 {
            # Date markers are 00110011
            assert { $markerRightValue == 3 }

            sectionname "Date"

            set dateValue [double]

            sectionvalue $dateValue
            move -8
            entry "Date value" $dateValue 8
            move 8

            endsection
            return [list $markerLeft $dateValue 8]
        }

        0101 {
            sectionname "String (ASCII)"

            set stringSize 0
            set stringSizeSize 0
            if { $markerRight == 1111 } {
                set stringSizeInt [parseInt]
                set stringSize [lindex $stringSizeInt 0]
                set stringSizeSize [lindex $stringSizeInt 1]
            } else {
                set stringSize $markerRightValue
                set stringSizeSize 1
            }

            move -$stringSizeSize
            entry "String size" $stringSize $stringSizeSize
            move $stringSizeSize

            set stringValue [ascii $stringSize]

            sectionvalue $stringValue
            move -$stringSize
            entry "String value" $stringValue $stringSize
            move $stringSize

            endsection
            return [list $markerLeft $stringValue $stringSize]
        }

        1101 {
            sectionname "Dict"

            set dictSize 0
            set dictSizeSize 0
            if { $markerRight == 1111 } {
                set dictSizeInt [parseInt]
                set dictSize [lindex $dictSizeInt 0]
                set dictSizeSize [lindex $dictSizeInt 1]
            } else {
                set dictSize $markerRightValue
                set dictSizeSize 1
            }

            sectionvalue $dictSize

            set valueOffset [expr { $dictSize * $::object_ref_size }]

            for { set i 0 } { $i < $dictSize } { incr i } {
                set keyRef [uint_n $::object_ref_size]
                move -$::object_ref_size
                entry "Key ref" $keyRef $::object_ref_size

                move $valueOffset

                set valueRef [uint_n $::object_ref_size]
                move -$::object_ref_size
                entry "Value ref" $valueRef $::object_ref_size

                move -$valueOffset

                move $::object_ref_size

                dict set dictValue $keyRef $valueRef
            }

            move $valueOffset

            endsection
            return [list $markerLeft $dictValue $dictSize]
        }

        default {
            die "Unknown object type: $markerLeft"
        }
    }
}

proc renderPlistTree {key i} {
    global objectTable

    lassign [lindex $objectTable $i] objectPos objectType objectValue objectSize

    jumpa $objectPos {
        switch $objectType {
            0001 -
            0011 -
            0101 {
                entry $key $objectValue $objectSize
            }

            1101 {
                section $key {
                    dict for { keyRef valueRef } $objectValue {
                        # Get key value
                        set key [lindex $objectTable $keyRef]

                        renderPlistTree [lindex $key 2] $valueRef
                    }
                }
            }
        }
    }
}

main_guard {
    puts "\n---\nApple Property List Binary Template"

    section -collapsed "Header" {
        set plistVersion [ascii 8]
        entry "Plist Version" $plistVersion 8 0

        # For now, only bplist00 is supported
        # TODO: assert won't work lmao
        # assert { "$plistVersion" != "bplist00" }
    }

    section -collapsed "Trailer" {
        jumpa [expr { [len] - 27 }] {
            bytes 1 "Sort version"

            set ::offset_table_offset_size [uint8]
            move -1
            entry "Offset table offset size" $::offset_table_offset_size 1
            move 1

            set ::object_ref_size [uint8]
            move -1
            entry "Object reference size" $::object_ref_size 1
            move 1

            set ::num_objects [uint64]
            move -8
            entry "Number of objects" $::num_objects 8
            move 8

            set ::top_object_offset [uint64]
            move -8
            entry "Top object offset" $::top_object_offset 8
            move 8

            set ::offset_table_start [uint64]
            move -8
            entry "Offset table start" $::offset_table_start 8
            move 8
        }
    }

    section -collapsed "Object table" {
        for { set i 0 } { $i < $::num_objects } { incr i } {
            lassign [parseObject] objectType objectValue objectSize
            lappend objectTable [list [pos] $objectType $objectValue $objectSize]
        }

    }

    renderPlistTree "Plist tree" $top_object_offset

    puts "---\n"
}

