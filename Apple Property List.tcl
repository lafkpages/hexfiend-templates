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

proc float_n {n} {
    switch $n {
        4 { return [float] }
        8 { return [double] }
        default {
            die "Invalid float_n size: $n"
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

    set markerRightValue [expr { $markerByteValue & 15 }]

    switch -glob $markerByte {
        "00000000" {
            sectionname "Null"

            sectionvalue "null"
            move -1
            entry "Null" "null" 1
            move 1

            endsection
            return [list $markerLeft "null" 1]
        }

        "00001000" -
        "00001001" {
            sectionname "Bool"

            set boolValue [expr { $markerRightValue == 8 ? "false" : "true" }]

            sectionvalue $boolValue
            move -1
            entry "Bool" $boolValue 1
            move 1

            endsection
            return [list $markerLeft $boolValue 1]
        }

        "0001*" {
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
            return [list $markerLeft $intValue [expr { $intSize + 1 }]]
        }

        "0010*" {
            sectionname "Real"

            # Real size is calculated same as Int size

            set realSize [expr { 2 ** $markerRightValue }]
            set realValue [float_n $realSize]

            move -$realSize
            move -1
            entry "Real size" $realSize 1
            move 1
            sectionvalue $realValue
            entry "Real value" $realValue $realSize
            move $realSize

            endsection
            return [list $markerLeft $realValue [expr { $realSize + 1 }]]
        }

        "00110011" {
            sectionname "Date"

            # https://www.epochconverter.com/coredata
            set dateValueRaw [double]
            set dateValue [clock format [expr { [::tcl::mathfunc::int $dateValueRaw] + 978307200 }]]

            sectionvalue $dateValue
            move -8
            entry "Date value" $dateValue 8
            entry "Date value (raw)" $dateValueRaw 8
            move 8

            endsection
            return [list $markerLeft $dateValue 9]
        }

        "0100*" {
            sectionname "Data"

            set dataSize 0
            set dataSizeSize 0
            if { $markerRight == 1111 } {
                set dataSizeInt [parseInt]
                set dataSize [lindex $dataSizeInt 0]
                set dataSizeSize [lindex $dataSizeInt 1]
            } else {
                set dataSize $markerRightValue
                set dataSizeSize 1
            }

            move -$dataSizeSize
            entry "Data size" $dataSize $dataSizeSize
            move $dataSizeSize

            if { $dataSize > 0 } {
                set dataValue [bytes $dataSize]

                sectionvalue $dataValue
                move -$dataSize
                entry "Data value" $dataValue $dataSize
                move $dataSize
            } else {
                set dataValue ""
            }

            endsection
            return [list $markerLeft $dataValue [expr { $dataSizeSize + $dataSize }]]
        }

        "0101*" {
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

            if { $stringSize > 0 } {
                set stringValue [ascii $stringSize]

                sectionvalue $stringValue
                move -$stringSize
                entry "String value" $stringValue $stringSize
                move $stringSize
            } else {
                set stringValue ""
            }


            endsection
            return [list $markerLeft $stringValue [expr { $stringSizeSize + $stringSize }]]
        }

        "0110*" {
            sectionname "String (Unicode)"

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
            entry "String size" "$stringSize chars ([expr { $stringSize * 2 }] bytes)" $stringSize $stringSizeSize
            move $stringSizeSize

            if { $stringSize > 0 } {
                set stringValue [bytes [expr { $stringSize * 2 }]]

                sectionvalue $stringValue
                move -$stringSize
                entry "String value" $stringValue $stringSize
                move $stringSize
            } else {
                set stringValue ""
            }

            endsection
            return [list $markerLeft $stringValue [expr { $stringSizeSize + $stringSize * 2 }]]
        }

        "1000*" {
            sectionname "UID"

            set uidSize [expr { $markerRight + 1 }]
            set uidValue [uint_n $uidSize]

            move -$uidSize
            move -1
            entry "UID size" $uidSize 1
            move 1
            sectionvalue $uidValue
            entry "UID value" $uidValue $uidSize
            move $uidSize

            endsection
            return [list $markerLeft $uidValue [expr { $uidSize + 1 }]]
        }

        "1010*" {
            sectionname "Array"

            set arraySize 0
            set arraySizeSize 0
            if { $markerRight == 1111 } {
                set arraySizeInt [parseInt]
                set arraySize [lindex $arraySizeInt 0]
                set arraySizeSize [lindex $arraySizeInt 1]
            } else {
                set arraySize $markerRightValue
                set arraySizeSize 1
            }

            move -$arraySizeSize
            entry "Array size" $arraySize $arraySizeSize
            move $arraySizeSize

            sectionvalue $arraySize

            set arrayValue [list]

            for { set i 0 } { $i < $arraySize } { incr i } {
                set arrayRef [uint_n $::object_ref_size]
                move -$::object_ref_size
                entry "Array ref" $arrayRef $::object_ref_size
                move $::object_ref_size

                lappend arrayValue $arrayRef
            }

            endsection
            return [list $markerLeft $arrayValue [expr { $arraySizeSize + $::object_ref_size * $arraySize }]]
        }

        "1101*" {
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

            set dictValue [dict create]
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
            return [list $markerLeft $dictValue [expr { $dictSizeSize + $valueOffset }]]
        }

        default {
            die "Unknown object type: $markerByte"
        }
    }
}

proc renderPlistTree {key i} {
    global objectTable

    lassign [lindex $objectTable $i] objectPos objectType objectValue objectSize

    switch $objectType {
        0000 {
            entry $key "bool:\t\t$objectValue" $objectSize $objectPos
        }

        0001 {
            entry $key "integer:\t$objectValue" $objectSize $objectPos
        }

        0010 {
            entry $key "real:\t\t$objectValue" $objectSize $objectPos
        }

        0011 {
            entry $key "date:\t\t$objectValue" $objectSize $objectPos
        }

        0100 {
            entry $key "data:\t\t$objectValue" $objectSize $objectPos
        }

        0101 {
            entry $key "string:\t$objectValue" $objectSize $objectPos
        }

        0110 {
            entry $key "string:\t$objectValue" $objectSize $objectPos
        }

        1000 {
            entry $key "uid:\t\t$objectValue" $objectSize $objectPos
        }

        1010 {
            section $key {
                for { set i 0 } { $i < [llength $objectValue] } { incr i } {
                    renderPlistTree $i [lindex $objectValue $i]
                }
            }
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

main_guard {
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
            set objectPos [pos]
            lassign [parseObject] objectType objectValue objectSize
            lappend objectTable [list $objectPos $objectType $objectValue $objectSize]
        }

    }

    renderPlistTree "Plist tree" $top_object_offset
}
