# .hidden = true;

set helpers_dir [file dirname [info script]]
set wish_path "/opt/homebrew/bin/wish"
set hexf_path "/opt/homebrew/bin/hexf"

set has_wish [file exists $wish_path]
set has_hexf [file exists $hexf_path]

proc ensure_wish {} {
    global has_wish

    if {!$has_wish} {
        global wish_path

        error "wish binary not found at $wish_path. Install it using Homebrew: brew install tcl-tk"
    }
}

proc ensure_hexf {} {
    global has_hexf

    if {!$has_hexf} {
        global hexf_path

        error "hexf binary not found at $hexf_path"
    }
}

# https://bluecrewforensics.com/varint-converter/
# https://github.com/fmoo/python-varint/blob/master/varint.py
proc parse_varint {} {
    set result 0
    set shift 0

    while {1} {
        set i [uint8]
        set result [expr {$result | (($i & 0x7f) << $shift)}]
        set shift [expr {$shift + 7}]

        if { !($i & 0x80) } {
            break
        }
    }

    return $result
}
