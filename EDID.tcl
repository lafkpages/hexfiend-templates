# https://en.wikipedia.org/wiki/Extended_Display_Identification_Data#EDID_1.4_data_format

include "Utility/General.tcl"

little_endian
requires 0 "00 FF FF FF FF FF FF 00"

main_guard {
    section "Header information" {
        move 8
        big_endian
        bytes 2 "Manufacturer ID"

        little_endian
        hex 2 "Manufacturer product code"

        section -collapsed "Serial number" {
            set serial [uint32]
            move -4

            sectionvalue $serial
            entry "Serial number (dec)" $serial 4 12
            hex 4 "Serial number (hex)"
        }

        section -collapsed "Manufacture date" {
            set week [uint8]
            set year [expr {[uint8] + 1990}]

            sectionvalue "$year, week $week"
            entry "Week" $week 1 16
            entry "Year" $year 1 17
        }

        section -collapsed "EDID version" {
            set version [uint8]
            set revision [uint8]

            sectionvalue "$version.$revision"
            entry "Version" $version 1 18
            entry "Revision" $revision 1 19
        }
    }

    section "Basic display parameters" {
        bytes 1 "Video input definition"

        set h_size [uint8]
        set v_size [uint8]
        entry "Horizontal screen size" "$h_size cm" 1 21
        entry "Vertical screen size" "$v_size cm" 1 22

        uint8 "Display gamma"

        bytes 1 "Supported features"
    }

    section -collapsed "Chromaticity coordinates" {
        bytes 1 "Red and green LSB"
        bytes 1 "Blue and white LS2B"
        uint8 "Red X MS8B"
        uint8 "Red Y MS8B"
        uint8 "Green X MS8B"
        uint8 "Green Y MS8B"
        uint8 "Blue X MS8B"
        uint8 "Blue Y MS8B"
        uint8 "White X MS8B"
        uint8 "White Y MS8B"
    }

    section -collapsed "Timing information" {
        section -collapsed "Established timings" {
            bytes 3 "Timings"
        }

        section -collapsed "Standard timings" {
            proc timing {} {
                set x_res [uint8]
                move -1

                if { $x_res == 0 } {
                    entry "Reserved" "" 2
                    return
                }

                entry "X resolution" [expr {($x_res + 31) * 8}] 1
                move 1
                bytes 1 "Aspect ratio and refresh rate"
            }

            for {set i 1} {$i <= 8} {incr i} {
                section "Standard timing $i" {
                    timing
                }
            }
        }

        section -collapsed "Timing descriptor" {
            # proc descriptor {} {

            # }

            bytes 18 "Preferred timing descriptor"
            bytes 18 "Timing descriptor 2"
            bytes 18 "Timing descriptor 3"
            bytes 18 "Timing descriptor 4"
        }
    }

    section -collapsed "Extension flag and checksum" {
        uint8 "Number of extensions"
        uint8 "Checksum byte"

        goto 0
        set bytes_sum 0
        for {set i 0} {$i < 128} {incr i} {
            set bytes_sum [expr {($bytes_sum + [uint8]) % 256}]
        }

        entry "Checksum" $bytes_sum 128 0
        check {$bytes_sum == 0}
    }
}