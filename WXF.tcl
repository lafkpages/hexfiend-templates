# .types = ( wxf );

include "Utility/General.tcl"
include "hexfiend-templates/utils/util.tcl"

# https://reference.wolfram.com/language/tutorial/WXFFormatDescription.html
# https://github.com/WolframResearch/WolframClientForPython/blob/master/wolframclient/deserializers/wxf/wxfparser.py

proc parse_part {} {
    section "Unknown part" {
        set part_type [uint8]

        switch $part_type {
            102 {
                sectionname "Function"

                move -1
                entry "Part type" "function" 1
                move 1

                set num_subparts [parse_varint]
                entry "Number of subparts" $num_subparts

                for {set i 0} {$i < $num_subparts} {incr i} {
                    parse_part
                }
            }
            67 {
                sectionname "Int8"

                move -1
                entry "Part type" "int8" 1
                move 1

                int8 "Integer value"
            }
            106 {
                sectionname "Int16"

                move -1
                entry "Part type" "int16" 1
                move 1

                int16 "Integer value"
            }
            105 {
                sectionname "Int32"

                move -1
                entry "Part type" "int32" 1
                move 1

                int32 "Integer value"
            }
            76 {
                sectionname "Int64"

                move -1
                entry "Part type" "int64" 1
                move 1

                int64 "Integer value"
            }
            114 {
                sectionname "IEEE double-precision real"

                move -1
                entry "Part type" "double" 1
                move 1

                double "Double value"
            }
            83 {
                sectionname "String"

                move -1
                entry "Part type" "string" 1
                move 1

                set str_length [parse_varint]

                ascii $str_length "String data"
            }
            115 {
                sectionname "Symbol"

                move -1
                entry "Part type" "symbol" 1
                move 1

                set symbol_length [parse_varint]

                ascii $symbol_length "Symbol data"
            }
            73 {
                sectionname "Big integer"

                move -1
                entry "Part type" "big integer" 1
                move 1

                set length [parse_varint]

                ascii $length "Big integer data"
            }
            82 {
                sectionname "Big real"

                move -1
                entry "Part type" "big real" 1
                move 1

                # TODO: for now, treat as a string

                set length [parse_varint]

                ascii $length "Big real data"
            }
            65 {
                sectionname "Association"

                move -1
                entry "Part type" "association" 1
                move 1

                set num_subparts [parse_varint]
                entry "Number of subparts" $num_subparts

                for {set i 0} {$i < $num_subparts} {incr i} {
                    parse_part
                }
            }
            45 {
                sectionname "Rule in association"

                move -1
                entry "Part type" "rule" 1
                move 1

                parse_part
                parse_part
            }
            default {
                die "Unknown part type: $part_type"
            }
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
            exec $wish_path [file join $util_dir "save_wxf.tcl"] << $data &
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
