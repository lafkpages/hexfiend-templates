# LiuCAS Expression Hash

include "Utility/General.tcl"
include "hexfiend-templates/helpers/util.tcl"

# See LiuCAS ExpressionKinds enum
set expression_kinds(0) "Addition"
set expression_kinds(1) "BooleanAnd"
set expression_kinds(2) "BooleanFalse"
set expression_kinds(3) "BooleanOr"
set expression_kinds(4) "BooleanTrue"
set expression_kinds(5) "Ceil"
set expression_kinds(6) "Cos"
set expression_kinds(7) "EulerNumber"
set expression_kinds(8) "Floor"
set expression_kinds(9) "Fraction"
set expression_kinds(10) "GCD"
set expression_kinds(11) "LCM"
set expression_kinds(12) "Log"
set expression_kinds(13) "Mod"
set expression_kinds(14) "Number"
set expression_kinds(15) "Pi"
set expression_kinds(16) "Placeholder"
set expression_kinds(17) "Power"
set expression_kinds(18) "Product"
set expression_kinds(19) "ProductSequence"
set expression_kinds(20) "Scoped"
set expression_kinds(21) "Sin"
set expression_kinds(22) "SquareRoot"
set expression_kinds(23) "SumSequence"
set expression_kinds(24) "Unknown"
set expression_kinds(255) "_Reserved"

proc read_expression {{key ""}} {
    section -collapsed "Unknown Expression type" {
        set kind [uint8 "Expression Kind"]
        set kind_name $::expression_kinds($kind)

        if { $key == "" } {
            sectionname $kind_name
        } else {
            sectionname "$key: $kind_name"
        }

        switch $kind {
            0 {
                set terms_count [uint8 "Terms Count"]

                for {set i 0} {$i < $terms_count} {incr i} {
                    read_expression "Term [expr {$i + 1}]"
                }
            }

            9 {
                read_expression "Numerator"
                read_expression "Denominator"
            }

            14 {
                set byte_length [uint32 "Byte length"]

                set value ""
                if {$byte_length == 0} {
                    set value 0
                } else {
                    binary scan [bytes $byte_length "Value"] c* signed_bytes

                    set value 0
                    set index 0
                    set most_significant 0

                    foreach signed_byte $signed_bytes {
                        set byte [expr {($signed_byte + 256) % 256}]

                        if {$index == 0} {
                            set most_significant $byte
                        }

                        set value [expr {($value << 8) | $byte}]
                        incr index
                    }

                    if {$most_significant & 0x80} {
                        set bit_count [expr {$byte_length * 8}]
                        set value [expr {$value - (1 << $bit_count)}]
                    }
                }

                sectionvalue $value
            }

            17 {
                read_expression "Base"
                read_expression "Exponent"
            }

            24 {
                set name_length [uint8 "Name Length"]
                set name [str $name_length utf8 "Name"]
                sectionvalue $name
            }

            6 -
            21 {
                # Single argument trigonometric functions
                read_expression "Angle"
            }

            5 -
            8 {
                # Single argument functions
                read_expression "Value"
            }

            2 -
            4 -
            7 -
            15 -
            16 {
                # Constants, no additional data
            }

            default {
                die "$kind_name expressions (kind $kind) not yet implemented."
            }
        }
    }
}

main_guard {
    ensure_wish

    read_expression
}
