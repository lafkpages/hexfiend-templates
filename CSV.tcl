# .types = ( public.comma-separated-values-text, csv );

include "Utility/General.tcl"

set sep ","

proc read_cell {} {
    global sep

    set data ""
    set quote false
    while {true} {
        set c [ascii 1]

        if {$c eq "\""} {
            set quote [expr {!$quote}]
            continue
        }

        if {!$quote} {
            if {$c eq $sep || $c eq "\n"} {
                break
            }
        }

        set data "$data$c"
    }

    # Move back the separator
    move -1

    return $data
}


main_guard {
    puts "Reading headers"
    set headers [list]
    section -collapsed Headers {
        while {true} {
            set a [pos]
            set header [read_cell]
            set b [pos]

            lappend headers $header
            puts $headers

            if {$b > $a} {
                entry "Header" $header [expr $b - $a] $a
            } else {
                entry "Header" $header
            }

            if {[ascii 1] eq "\n"} {
                break
            }
        }
    }

    puts "\nReading rows\n"
    set i 0
    while {true} {
        incr i
        puts "Reading row: $i"
        section "Row $i" {
            set j 0
            while {true} {
                set a [pos]
                set data [read_cell]
                set b [pos]

                set header [lindex $headers $j]

                if {$b > $a} {
                    entry $header $data [expr $b - $a] $a
                } else {
                    entry $header $data
                }
                incr j

                if {[ascii 1] eq "\n"} {
                    break
                }
            }

            if {[end]} {
                break
            }
        }
    }
}

puts "\n-----\n"
