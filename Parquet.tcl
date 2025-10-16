# Apache Parquet files
#
# https://parquet.apache.org/docs/file-format/
# https://github.com/skale-me/node-parquet/blob/master/lib/parquet.js
# https://github.com/apache/parquet-format/blob/master/src/main/thrift/parquet.thrift

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

proc enum_name {value names} {
    if {[string is integer -strict $value] && $value >= 0 && $value < [llength $names]} {
        return [lindex $names $value]
    }

    return $value
}

proc parse_schema_impl {schema idx path nodesVar leafMapVar} {
    upvar $nodesVar nodes
    upvar $leafMapVar leaf_map

    if {$idx >= [llength $schema]} {
        return $idx
    }

    set schema_fields [lindex $schema $idx]
    set schema_dict [fields_to_dict $schema_fields]

    set name [format "Schema Element %d" $idx]
    if {[dict exists $schema_dict 4]} {
        set decoded_name [decode_utf8 [dict get $schema_dict 4]]
        if {$decoded_name ne ""} {
            set name $decoded_name
        }
    }

    if {[llength $path] == 0} {
        set current_path [list $name]
    } else {
        set current_path [concat $path [list $name]]
    }

    set num_children 0
    if {[dict exists $schema_dict 5]} {
        set num_children [dict get $schema_dict 5]
    }

    set node [dict create index $idx dict $schema_dict path $current_path num_children $num_children]
    lappend nodes $node

    if {$num_children == 0} {
        set full_key [join $current_path "/"]
        if {$full_key ne ""} {
            dict set leaf_map $full_key $node
        }

        if {[llength $current_path] > 1} {
            set short_key [join [lrange $current_path 1 end] "/"]
            if {$short_key ne ""} {
                dict set leaf_map $short_key $node
            }
        }
    }

    set next_idx [expr {$idx + 1}]
    for {set i 0} {$i < $num_children} {incr i} {
        set next_idx [parse_schema_impl $schema $next_idx $current_path nodes leaf_map]
    }

    return $next_idx
}

proc parse_schema {schema} {
    set nodes {}
    set leaf_map {}
    parse_schema_impl $schema 0 {} nodes leaf_map
    return [list $nodes $leaf_map]
}

set TypeNames "BOOLEAN INT32 INT64 INT96 FLOAT DOUBLE BYTE_ARRAY FIXED_LEN_BYTE_ARRAY"
set RepetitionTypeNames "REQUIRED OPTIONAL REPEATED"
set EncodingNames "PLAIN PLAIN_DICTIONARY RLE BIT_PACKED DELTA_BINARY_PACKED DELTA_LENGTH_BYTE_ARRAY DELTA_BYTE_ARRAY RLE_DICTIONARY BYTE_STREAM_SPLIT"
set CompressionCodecNames "UNCOMPRESSED SNAPPY GZIP LZO BROTLI LZ4 ZSTD LZ4_RAW"

main_guard {
    goto [len]
    move -8
    set mlen [uint32]
    move -4
    move -$mlen

    set metadata_dict [fields_to_dict [read_obj]]

    goto [len]
    move -8
    move -$mlen

    section "Metadata" {
        if {[dict exists $metadata_dict 1]} {
            entry "Version" [dict get $metadata_dict 1] 1
        }

        set schema_nodes {}
        set schema_leaf_map {}
        if {[dict exists $metadata_dict 2]} {
            set schema [dict get $metadata_dict 2]
            set parsed_schema [parse_schema $schema]
            set schema_nodes [lindex $parsed_schema 0]
            set schema_leaf_map [lindex $parsed_schema 1]

            section "Schema" {
                foreach node $schema_nodes {
                    set schema_dict [dict get $node dict]
                    set entry_name [join [dict get $node path] "."]
                    if {$entry_name eq ""} {
                        set entry_name [format "Schema Element %d" [dict get $node index]]
                    }

                    section $entry_name {
                        if {[dict exists $schema_dict 1]} {
                            entry "Type" [enum_name [dict get $schema_dict 1] $TypeNames]
                        }

                        if {[dict exists $schema_dict 2]} {
                            entry "Type Length" [dict get $schema_dict 2]
                        }

                        if {[dict exists $schema_dict 3]} {
                            entry "Repetition Type" [enum_name [dict get $schema_dict 3] $RepetitionTypeNames]
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
            set row_groups [dict get $metadata_dict 4]

            section "Row Groups" {
                for {set i 0} {$i < [llength $row_groups]} {incr i} {
                    set row_group_fields [lindex $row_groups $i]
                    set row_group_dict [fields_to_dict $row_group_fields]

                    section "Row Group $i" {
                        if {[dict exists $row_group_dict 2]} {
                            entry "Total Byte Size" [dict get $row_group_dict 2]
                        }

                        if {[dict exists $row_group_dict 3]} {
                            entry "Num Rows" [dict get $row_group_dict 3]
                        }

                        if {[dict exists $row_group_dict 1]} {
                            set columns [dict get $row_group_dict 1]

                            section "Columns" {
                                for {set j 0} {$j < [llength $columns]} {incr j} {
                                    set column_fields [lindex $columns $j]
                                    set column_dict [fields_to_dict $column_fields]

                                    set column_metadata_dict {}
                                    set decoded_path {}
                                    set column_schema_node ""
                                    set schema_dict {}
                                    set schema_type_name ""
                                    set schema_repetition ""
                                    set column_meta_type_name ""

                                    if {[dict exists $column_dict 3]} {
                                        set column_metadata_fields [dict get $column_dict 3]
                                        set column_metadata_dict [fields_to_dict $column_metadata_fields]

                                        if {[dict exists $column_metadata_dict 3]} {
                                            foreach component [dict get $column_metadata_dict 3] {
                                                lappend decoded_path [decode_utf8 $component]
                                            }

                                            set lookup_key [join $decoded_path "/"]
                                            if {$lookup_key ne ""} {
                                                if {[dict exists $schema_leaf_map $lookup_key]} {
                                                    set column_schema_node [dict get $schema_leaf_map $lookup_key]
                                                }
                                            }
                                        }

                                        if {[dict exists $column_metadata_dict 1]} {
                                            set column_meta_type_name [enum_name [dict get $column_metadata_dict 1] $TypeNames]
                                        }
                                    }

                                    if {$column_schema_node ne ""} {
                                        set schema_dict [dict get $column_schema_node dict]
                                        if {[dict exists $schema_dict 1]} {
                                            set schema_type_name [enum_name [dict get $schema_dict 1] $TypeNames]
                                        }
                                        if {[dict exists $schema_dict 3]} {
                                            set schema_repetition [enum_name [dict get $schema_dict 3] $RepetitionTypeNames]
                                        }
                                    }

                                    set column_label [format "Column Chunk %d" $j]
                                    if {[llength $decoded_path] > 0} {
                                        set column_label [format "Column %s" [join $decoded_path "."]]
                                    }

                                    set column_type_label ""
                                    if {$schema_type_name ne ""} {
                                        set column_type_label $schema_type_name
                                    } elseif {$column_meta_type_name ne ""} {
                                        set column_type_label $column_meta_type_name
                                    }

                                    if {$column_type_label ne ""} {
                                        set column_section_name [format "%s (%s)" $column_label $column_type_label]
                                    } else {
                                        set column_section_name $column_label
                                    }

                                    section $column_section_name {
                                        if {[llength $decoded_path] > 0} {
                                            entry "Schema Path" [join $decoded_path "."]
                                        }

                                        if {$schema_repetition ne ""} {
                                            entry "Repetition Type" $schema_repetition
                                        }

                                        if {[dict size $schema_dict] > 0} {
                                            if {[dict exists $schema_dict 10]} {
                                                entry "Logical Type" [dict get $schema_dict 10]
                                            }

                                            if {[dict exists $schema_dict 9]} {
                                                entry "Field ID" [dict get $schema_dict 9]
                                            }

                                            if {[dict exists $schema_dict 7]} {
                                                entry "Scale" [dict get $schema_dict 7]
                                            }

                                            if {[dict exists $schema_dict 8]} {
                                                entry "Precision" [dict get $schema_dict 8]
                                            }
                                        }

                                        if {[dict exists $column_dict 1]} {
                                            entry "File Path" [decode_utf8 [dict get $column_dict 1]]
                                        }

                                        if {[dict exists $column_dict 2]} {
                                            entry "File Offset" [dict get $column_dict 2]
                                        }

                                        if {[dict exists $column_dict 4]} {
                                            entry "Offset Index Offset" [dict get $column_dict 4]
                                        }

                                        if {[dict exists $column_dict 5]} {
                                            entry "Offset Index Length" [dict get $column_dict 5]
                                        }

                                        if {[dict exists $column_dict 6]} {
                                            entry "Column Index Offset" [dict get $column_dict 6]
                                        }

                                        if {[dict exists $column_dict 7]} {
                                            entry "Column Index Length" [dict get $column_dict 7]
                                        }

                                        if {[dict exists $column_dict 8]} {
                                            entry "Crypto Metadata" [dict get $column_dict 8]
                                        }

                                        if {[dict exists $column_dict 9]} {
                                            entry "Encrypted Column Metadata" [dict get $column_dict 9]
                                        }

                                        if {[dict size $column_metadata_dict] > 0} {
                                            section "Column Meta Data" {
                                                if {$column_meta_type_name ne ""} {
                                                    entry "Type" $column_meta_type_name
                                                } elseif {[dict exists $column_metadata_dict 1]} {
                                                    entry "Type" [dict get $column_metadata_dict 1]
                                                }

                                                if {[dict exists $column_metadata_dict 2]} {
                                                    set encodings {}
                                                    foreach encoding [dict get $column_metadata_dict 2] {
                                                        lappend encodings [enum_name $encoding $EncodingNames]
                                                    }
                                                    entry "Encodings" [join $encodings ", "]
                                                }

                                                if {[llength $decoded_path] > 0} {
                                                    entry "Path In Schema" [join $decoded_path "."]
                                                }

                                                if {[dict exists $column_metadata_dict 4]} {
                                                    entry "Codec" [enum_name [dict get $column_metadata_dict 4] $CompressionCodecNames]
                                                }

                                                if {[dict exists $column_metadata_dict 5]} {
                                                    entry "Num Values" [dict get $column_metadata_dict 5]
                                                }

                                                if {[dict exists $column_metadata_dict 6]} {
                                                    entry "Total Uncompressed Size" [dict get $column_metadata_dict 6]
                                                }

                                                if {[dict exists $column_metadata_dict 7]} {
                                                    entry "Total Compressed Size" [dict get $column_metadata_dict 7]
                                                }

                                                if {[dict exists $column_metadata_dict 8]} {
                                                    entry "Key Value Metadata" [dict get $column_metadata_dict 8]
                                                }

                                                if {[dict exists $column_metadata_dict 9]} {
                                                    entry "Data Page Offset" [dict get $column_metadata_dict 9]
                                                }

                                                if {[dict exists $column_metadata_dict 10]} {
                                                    entry "Index Page Offset" [dict get $column_metadata_dict 10]
                                                }

                                                if {[dict exists $column_metadata_dict 11]} {
                                                    entry "Dictionary Page Offset" [dict get $column_metadata_dict 11]
                                                }

                                                if {[dict exists $column_metadata_dict 12]} {
                                                    entry "Statistics" [dict get $column_metadata_dict 12]
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        if {[dict exists $row_group_dict 4]} {
                            entry "Sorting Columns" [dict get $row_group_dict 4]
                        }

                        if {[dict exists $row_group_dict 5]} {
                            entry "File Offset" [dict get $row_group_dict 5]
                        }

                        if {[dict exists $row_group_dict 6]} {
                            entry "Total Compressed Size" [dict get $row_group_dict 6]
                        }

                        if {[dict exists $row_group_dict 7]} {
                            entry "Ordinal" [dict get $row_group_dict 7]
                        }
                    }
                }
            }
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
