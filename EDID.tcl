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

        section -collapsed "Timing/monitor descriptors" {
            proc descriptor {i} {
                sentry 18 {
                    set pixel_clock [uint16]
                    move -2

                    if { $pixel_clock == 0 } {
                        move 3

                        set descriptor_type [hex 1]

                        switch $descriptor_type {
                            0xFF {
                                ascii 14 "$i. Serial number"
                            }
                            0xFD {
                                section "$i. Display range limits" {
                                    binary scan [bytes 1] Bu8 offsets
                                    # move -1
                                    # entry "Offsets for display range limits" "0b$offsets" 1
                                    # move 1

                                    set min_ver_rate [uint8]
                                    set max_ver_rate [uint8]
                                    set min_hor_rate [uint8]
                                    set max_hor_rate [uint8]

                                    set hor_rate_offsets [string range $offsets 4 5]
                                    switch $hor_rate_offsets {
                                        00 {}
                                        10 {
                                            incr max_hor_rate 255
                                        }
                                        11 {
                                            incr max_hor_rate 255
                                            incr min_hor_rate 255
                                        }
                                        default {
                                            report "Invalid horizontal rate offsets"
                                        }
                                    }

                                    set ver_rate_offsets [string range $offsets 6 7]
                                    switch $ver_rate_offsets {
                                        00 {}
                                        10 {
                                            incr max_ver_rate 255
                                        }
                                        11 {
                                            incr max_ver_rate 255
                                            incr min_ver_rate 255
                                        }
                                        default {
                                            report "Invalid vertical rate offsets"
                                        }
                                    }

                                    move -4
                                    entry "Minimum vertical field rate" $min_ver_rate 1
                                    move 1
                                    entry "Maximum vertical field rate" $max_ver_rate 1
                                    move 1
                                    entry "Minimum horizontal line rate" $min_hor_rate 1
                                    move 1
                                    entry "Maximum horizontal line rate" $max_hor_rate 1
                                    move 1

                                    uint8 "Maximum pixel clock rate"

                                    set ext_timing_info_type [uint8]
                                    switch $ext_timing_info_type {
                                        0 -
                                        1 {
                                            set ext_timing_info [hex 7]
                                            check {$ext_timing_info eq "0x0A202020202020"}
                                        }
                                        2 {
                                            # TODO
                                            move 7
                                        }
                                        4 {
                                            # TODO
                                            move 7
                                        }
                                        default {
                                            report "Invalid extended timing information type: $ext_timing_info_type"
                                            move 7
                                        }
                                    }
                                }
                            }
                            0xFE {
                                ascii 14 "$i. Unspecified text"
                            }
                            0xFC {
                                ascii 14 "$i. Monitor name"
                            }
                            0x10 {
                                bytes 14 "$i. Dummy descriptor"
                            }
                            default {
                                section "$i. Monitor descriptor" {
                                    move -2
                                    entry "Descriptor type" $descriptor_type 1
                                    move 16
                                }
                            }
                        }
                    } else {
                        set label "$i. Timing descriptor"
                        if { $i == 1 } {
                            append label " (preferred)"
                        }

                        section $label {
                            set pixel_clock_mhz [expr {$pixel_clock / 100.0}]
                            entry "Pixel clock" "$pixel_clock_mhz MHz" 2

                            move 2

                            uint8 "Horizontal active pixels 8LSB"
                            uint8 "Horizontal blanking pixels 8LSB"
                            bytes 1 "Horizontal active/blanking pixels MSB"
                            uint8 "Vertical active lines 8LSB"
                            uint8 "Vertical blanking lines 8LSB"
                            bytes 1 "Vertical active/blanking lines MSB"
                            uint8 "Horizontal sync offset 8LSB"
                            uint8 "Horizontal sync pulse width 8LSB"
                            bytes 1 "Vertical sync offset/pulse width 4LSB"
                            bytes 1 "Horizontal/vertical sync offset/pulse 2MSB"
                            uint8 "Horizontal image size 8LSB"
                            uint8 "Vertical image size 8LSB"
                            bytes 1 "Horizontal/vertical image size 4MSB"
                            uint8 "Horizontal border pixels"
                            uint8 "Vertical border lines"
                            bytes 1 "Features"
                        }
                    }
                }
            }

            descriptor 1
            for {set i 2} {$i <= 4} {incr i} {
                descriptor $i
            }
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