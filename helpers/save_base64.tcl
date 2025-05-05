# .hidden = true;

set helpers_dir [file dirname [info script]]
source [file join $helpers_dir "util.tcl"]

wm state . withdrawn

set path [tk_getSaveFile]

if { $path == "" } {
    exit
}

fconfigure stdin -translation binary
set raw_data [read stdin]
set data [binary decode base64 $raw_data]

set fd [open $path "w"]
puts -nonewline $fd $data
close $fd

puts $path

if { $has_hexf } {
    exec $hexf_path $path
}

exit
