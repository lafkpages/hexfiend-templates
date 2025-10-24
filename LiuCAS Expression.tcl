# LiuCAS Expression Hash

include "Utility/General.tcl"
include "hexfiend-templates/helpers/util.tcl"

# See LiuCAS ExpressionKinds enum
set expression_kinds(0) "Addition"
set expression_kinds(1) "BooleanAnd"
set expression_kinds(2) "BooleanFalse"
set expression_kinds(3) "BooleanNot"
set expression_kinds(4) "BooleanOr"
set expression_kinds(5) "BooleanTrue"
set expression_kinds(6) "Ceil"
set expression_kinds(7) "Cos"
set expression_kinds(8) "EulerNumber"
set expression_kinds(9) "Floor"
set expression_kinds(10) "Fraction"
set expression_kinds(11) "GCD"
set expression_kinds(12) "LCM"
set expression_kinds(13) "Log"
set expression_kinds(14) "Mod"
set expression_kinds(15) "Number"
set expression_kinds(16) "Pi"
set expression_kinds(17) "Placeholder"
set expression_kinds(18) "Power"
set expression_kinds(19) "Product"
set expression_kinds(20) "ProductSequence"
set expression_kinds(21) "Scoped"
set expression_kinds(22) "Sin"
set expression_kinds(23) "SquareRoot"
set expression_kinds(24) "SumSequence"
set expression_kinds(25) "Unknown"
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
            0 -
            1 -
            4 {
                set terms_count [uint8 "Terms Count"]

                for {set i 0} {$i < $terms_count} {incr i} {
                    read_expression "Term [expr {$i + 1}]"
                }
            }

            10 {
                read_expression "Numerator"
                read_expression "Denominator"
            }

            11 -
            12 {
                read_expression "A"
                read_expression "B"
            }

            14 {
                read_expression "Dividend"
                read_expression "Divisor"
            }

            15 {
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

            18 {
                read_expression "Base"
                read_expression "Exponent"
            }

            19 {
                set factors_count [uint8 "Factors Count"]

                for {set i 0} {$i < $factors_count} {incr i} {
                    read_expression "Factor [expr {$i + 1}]"
                }
            }

            25 {
                set name_length [uint8 "Name Length"]
                set name [str $name_length utf8 "Name"]
                sectionvalue $name
            }

            7 -
            22 {
                # Single argument trigonometric functions
                read_expression "Angle"
            }

            3 -
            6 -
            9 -
            23 {
                # Single argument functions
                read_expression "Value"
            }

            2 -
            5 -
            8 -
            16 -
            17 {
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
