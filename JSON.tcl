# .types = ( public.json, json, jsonc, json5 );

include "Utility/General.tcl"

package require json

set d [json::json2dict [bytes [len]]]

# Helper procedure to identify Tcl data types roughly corresponding to JSON types
proc getInfoType {value} {
    if {[catch {dict keys $value} keys]} {
        # Not a dictionary
        if {[catch {llength $value} len]} {
            # Not a list either (or error checking length)
            return "scalar"
        } else {
            # Could be a list or just a string with spaces. More robust check:
            if {[string is list $value] && $len > 1} {
                return "list"
            } else {
                # Check if it might be an empty list represented oddly or just a scalar
                if {$len == 0 && [string length $value] == 0} {
                    # Could be empty list or empty string - ambiguity
                    return "empty list/string"
                } elseif {$len == 1 && [lindex $value 0] == $value} {
                    # Likely a scalar that happens to be a valid list of one element
                    return "scalar"
                } else {
                    # Treat as list if llength worked and wasn't scalar-like
                    return "list"
                }
            }
        }
    } else {
        return "dictionary"
    }
}

proc walkJson {key value { isSub 1 }} {
    set valueType [getInfoType $value]

    switch $valueType {
        "dictionary" {
            if { $isSub } {
                section $key
            }

            foreach {k v} [dict get $value] {
                walkJson $k $v
            }

            if { $isSub } {
                endsection
            }
        }
        "list" {
            if { $isSub } {
                section $key
            }

            foreach {i v} [array get $value] {
                walkJson $i $v
            }

            if { $isSub } {
                endsection
            }
        }
        "scalar" {
            entry $key $value
        }
        default {
            report "Unknown type: $valueType"
        }
    }
}

main_guard {
    walkJson "" $d 0
}
