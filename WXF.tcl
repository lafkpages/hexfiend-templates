# .types = ( wxf );

include "Utility/General.tcl"
include "hexfiend-templates/helpers/util.tcl"

# https://reference.wolfram.com/language/tutorial/WXFFormatDescription.html
# https://github.com/WolframResearch/WolframClientForPython/blob/master/wolframclient/deserializers/wxf/wxfparser.py

proc parse_part {} {
    set part_type [uint8]

    switch $part_type {
        102 {
            section "Function" {
                move -1
                entry "Part type" "function" 1
                move 1

                set num_subparts [parse_varint]
                entry "Number of subparts" $num_subparts

                for {set i 0} {$i < $num_subparts} {incr i} {
                    parse_part
                }
            }
        }
        67 {
            section -collapsed "Int8" {
                move -1
                entry "Part type" "int8" 1
                move 1

                set value [int8]
                sectionvalue $value
                move -1
                entry "Integer value" $value 1
                move 1
            }
        }
        106 {
            section -collapsed "Int16" {
                move -1
                entry "Part type" "int16" 1
                move 1

                set value [int16]
                sectionvalue $value
                move -2
                entry "Integer value" $value 2
                move 2
            }
        }
        105 {
            section -collapsed "Int32" {
                move -1
                entry "Part type" "int32" 1
                move 1

                set value [int32]
                sectionvalue $value
                move -4
                entry "Integer value" $value 4
                move 4
            }
        }
        76 {
            section -collapsed "Int64" {
                move -1
                entry "Part type" "int64" 1
                move 1

                set value [int64]
                sectionvalue $value
                move -8
                entry "Integer value" $value 8
                move 8
            }
        }
        114 {
            section -collapsed "IEEE double-precision real" {
                move -1
                entry "Part type" "double" 1
                move 1

                set value [double]
                sectionvalue $value
                move -8
                entry "Double value" $value 8
                move 8
            }
        }
        83 {
            section -collapsed "String" {
                move -1
                entry "Part type" "string" 1
                move 1

                set str_length [parse_varint]

                set value [ascii $str_length]
                sectionvalue $value
                move -$str_length
                entry "String data" $value $str_length
                move $str_length
            }
        }
        115 {
            section -collapsed "Symbol" {
                move -1
                entry "Part type" "symbol" 1
                move 1

                set symbol_length [parse_varint]

                set value [ascii $symbol_length]
                sectionvalue $value
                move -$symbol_length
                entry "Symbol data" $value $symbol_length
                move $symbol_length
            }
        }
        73 {
            section -collapsed "Big integer" {
                move -1
                entry "Part type" "big integer" 1
                move 1

                set length [parse_varint]

                set value [ascii $length]
                sectionvalue $value
                move -$length
                entry "Big integer data" $value $length
                move $length
            }
        }
        82 {
            section -collapsed "Big real" {
                move -1
                entry "Part type" "big real" 1
                move 1

                # TODO: for now, treat as a string

                set length [parse_varint]

                set value [ascii $length]
                sectionvalue $value
                move -$length
                entry "Big real data" $value $length
                move $length
            }
        }
        65 {
            section "Association" {
                move -1
                entry "Part type" "association" 1
                move 1

                set num_subparts [parse_varint]
                entry "Number of subparts" $num_subparts

                for {set i 0} {$i < $num_subparts} {incr i} {
                    parse_part
                }
            }
        }
        45 {
            section "Rule in association" {
                move -1
                entry "Part type" "rule" 1
                move 1

                parse_part
                parse_part
            }
        }
        default {
            die "Unknown part type: $part_type"
        }
    }
}

main_guard {
    section "Header" {
        set version ""
        set compress 0

        set next_byte [bytes 1]
        assert { $next_byte == 8 } "Invalid version"
        set version $next_byte

        entry "Version" $version 1 0

        set next_byte [bytes 1]
        if { $next_byte == "C" } {
            set compress 1
            set next_byte [bytes 1]

            entry "Compressed" "yes" 1 1
        } else {
            entry "Compressed" "no"
        }
        if { $next_byte != ":" } {
            die "Invalid header"
        }
    }


    set data [bytes eof]
    if { $compress } {
        set data [zlib_uncompress $data]

        global has_wish
        global wish_path

        if { $has_wish } {
            exec $wish_path [file join $helpers_dir "save_wxf.tcl"] << $data &
        }

        die "Directly reading compressed WXF data is not yet implemented. Please use the 'Save WXF' option to extract the data."
        goto 3
    } else {
        goto 2
    }

    section "Data" {
        while { ![end] } {
            parse_part
        }
    }
}
