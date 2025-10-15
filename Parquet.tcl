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

proc read_value {type value_arg} {
    upvar $value_arg value

    switch $type {
        3 {
            # byte
            set value [zigzag_decode [parse_varint]]
            return 0
        }

        4 {
            # int16
            set value [zigzag_decode [parse_varint]]
            return 0
        }

        5 {
            # int32
            set value [zigzag_decode [parse_varint]]
            return 0
        }

        6 {
            # int64
            set value [zigzag_decode [parse_varint]]
            return 0
        }

        7 {
            # double (stored as little-endian IEEE 754; keep raw bytes)
            set value [bytes 8]
            return 0
        }

        8 {
            set len [parse_varint]
            set value [bytes $len]
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
            set value {}

            for {set i 0} {$i < $n} {incr i} {
                if {$list_type == 1 || $list_type == 2} {
                    # boolean values are encoded inline as single bytes
                    set bool_byte [uint8]
                    lappend value [expr {$bool_byte == 1}]
                } else {
                    set _value ""
                    read_value $list_type _value
                    lappend value $_value
                }
            }

            return 0
        }

        12 {
            # struct
            set value [read_obj]
            return 0
        }

        default {
            die "Unknown object type $type"
        }
    }
}

proc read_obj {} {
    set fields ""
    set last_field_id 0

    while {1} {
        set header [uint8]

        if {$header == 0} {
            break
        }

        set type [expr {$header & 15}]
        set delta [expr {$header >> 4}]

        if {$delta == 0} {
            set field_id [zigzag_decode [parse_varint]]
        } else {
            set field_id [expr {$last_field_id + $delta}]
        }

        set last_field_id $field_id

        if {$type == 1 || $type == 2} {
            set value [expr {$type == 1}]
        } else {
            set value ""
            read_value $type value
        }

        lappend fields [list $field_id $value]
    }

    return $fields
}

proc fields_to_dict {fields} {
    set dict {}

    foreach field $fields {
        dict set dict [lindex $field 0] [lindex $field 1]
    }

    return $dict
}

proc decode_utf8 {value} {
    if {[catch {encoding convertfrom utf-8 $value} decoded]} {
        return $value
    }

    return $decoded
}

set TypeNames "BOOLEAN INT32 INT64 INT96 FLOAT DOUBLE BYTE_ARRAY FIXED_LEN_BYTE_ARRAY"
set RepetitionTypeNames "REQUIRED OPTIONAL REPEATED"

main_guard {
    goto [len]
    move -8
    set mlen [uint32 "mlen"]
    move -4
    move -$mlen
    bytes $mlen "metadata"
    move -$mlen

    set metadata_dict [fields_to_dict [read_obj]]

    section "Metadata" {
        if {[dict exists $metadata_dict 1]} {
            entry "Version" [dict get $metadata_dict 1]
        }

        if {[dict exists $metadata_dict 2]} {
            set schema [dict get $metadata_dict 2]

            section "Schema" {
                for {set i 0} {$i < [llength $schema]} {incr i} {
                    set schema_fields [lindex $schema $i]
                    set schema_dict [fields_to_dict $schema_fields]

                    set entry_name "Schema Element $i"
                    if {[dict exists $schema_dict 4]} {
                        set entry_name [decode_utf8 [dict get $schema_dict 4]]
                    }

                    section $entry_name {
                        if {[dict exists $schema_dict 1]} {
                            set type_id [dict get $schema_dict 1]
                            if {$type_id >= 0 && $type_id < [llength $TypeNames]} {
                                entry "Type" [lindex $TypeNames $type_id]
                            } else {
                                entry "Type" $type_id
                            }
                        }

                        if {[dict exists $schema_dict 2]} {
                            entry "Type Length" [dict get $schema_dict 2]
                        }

                        if {[dict exists $schema_dict 3]} {
                            set repetition_id [dict get $schema_dict 3]
                            if {$repetition_id >= 0 && $repetition_id < [llength $RepetitionTypeNames]} {
                                entry "Repetition Type" [lindex $RepetitionTypeNames $repetition_id]
                            } else {
                                entry "Repetition Type" $repetition_id
                            }
                        }

                        if {[dict exists $schema_dict 4]} {
                            entry "Name" [decode_utf8 [dict get $schema_dict 4]]
                        }

                        if {[dict exists $schema_dict 5]} {
                            entry "Num Children" [dict get $schema_dict 5]
                        }

                        if {[dict exists $schema_dict 6]} {
                            entry "Converted Type" [dict get $schema_dict 6]
                        }

                        if {[dict exists $schema_dict 7]} {
                            entry "Scale" [dict get $schema_dict 7]
                        }

                        if {[dict exists $schema_dict 8]} {
                            entry "Precision" [dict get $schema_dict 8]
                        }

                        if {[dict exists $schema_dict 9]} {
                            entry "Field ID" [dict get $schema_dict 9]
                        }

                        if {[dict exists $schema_dict 10]} {
                            entry "Logical Type" [dict get $schema_dict 10]
                        }
                    }
                }
            }
        }

        if {[dict exists $metadata_dict 3]} {
            entry "Num Rows" [dict get $metadata_dict 3]
        }

        if {[dict exists $metadata_dict 4]} {
            entry "Row Groups" [dict get $metadata_dict 4]
        }

        if {[dict exists $metadata_dict 5]} {
            entry "Key Value Metadata" [dict get $metadata_dict 5]
        }

        if {[dict exists $metadata_dict 6]} {
            entry "Created By" [decode_utf8 [dict get $metadata_dict 6]]
        }

        if {[dict exists $metadata_dict 7]} {
            entry "Column Orders" [dict get $metadata_dict 7]
        }

        if {[dict exists $metadata_dict 8]} {
            entry "Encryption Algorithm" [dict get $metadata_dict 8]
        }

        if {[dict exists $metadata_dict 9]} {
            entry "Footer Signature" [dict get $metadata_dict 9]
        }
    }
}
