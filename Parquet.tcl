# Apache Parquet files
#
# https://parquet.apache.org/docs/file-format/
# https://github.com/skale-me/node-parquet/blob/master/lib/parquet.js

include "Utility/General.tcl"
include "hexfiend-templates/helpers/util.tcl"

requires 0 "50415231"
requires [expr [len] - 4] "50415231"

proc zigzag_decode {n} {
    return [expr {($n >> 1) ^ (-1 * ($n & 1))}]
}

proc read_given_type {type value_arg} {
    upvar $value_arg value

    switch $type {
        0 {
            # null
            set value ""
            entry "Null" ""
            return 1
        }

        4 {
            # int16
            set value [zigzag_decode [parse_varint]]
            entry "Int16" $value
            return 0
        }

        5 {
            # int32
            set value [zigzag_decode [parse_varint]]
            entry "Int32" $value
            return 0
        }

        6 {
            # int64
            set value [zigzag_decode [parse_varint]]
            entry "Int64" $value
            return 0
        }

        8 {
            set len [parse_varint]
            set value [bytes $len]
            move -$len
            entry "Bytes" $value $len
            move $len
            return 0
        }

        9 {
            # list
            set list_header [uint8]
            set n [expr {($list_header >> 4) & 15}]

            if {$n == 15} {
                set n [parse_varint]
            }

            set list_type [expr {$list_header & 15}]
            set value ""

            section "List" {
                sectionvalue $n

                for {set i 0} {$i < $n} {incr i} {
                    set _value ""
                    read_given_type $list_type _value
                    lappend value $_value
                }
            }

            return 0
        }

        12 {
            # struct
            section "Struct" {
                set value [read_obj]
            }

            return 0
        }

        default {
            die "Unknown object type $type"
        }
    }
}

proc read_type {value_arg} {
    upvar $value_arg value

    set header [uint8]

    set type [expr {$header & 15}]
    if {$type == 0} {
        set value ""
        entry "Null" ""
        return 1
    }

    read_given_type $type value
}

proc read_obj {} {
    set values ""
    set value ""
    while {1} {
        if {[read_type value]} {
            break
        }
        lappend values $value
    }

    return $values
}

main_guard {
    goto [len]
    move -8
    set mlen [uint32 "mlen"]
    move -4
    move -$mlen
    bytes $mlen "metadata"
    move -$mlen

    set metadata [read_obj]

    section "Metadata" {
        entry "Version" [lindex $metadata 0]
        entry "Schema" [lindex $metadata 1]
        entry "Num Rows" [lindex $metadata 2]
    }
}
