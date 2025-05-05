# .hidden = true;

set helpers_dir [file dirname [info script]]
source [file join $helpers_dir "util.tcl"]

wm state . withdrawn

# https://wiki.tcl-lang.org/page/bitmap
if { [tk_dialog .confirm "WXF Compressed" "This WXF data is compressed. Would you like to extract it to a separate file?" question 0 Yes No] } {
    exit
}

set path [tk_getSaveFile -title "Save WXF" -defaultextension ".wxf" -filetypes {{"WXF files" {.wxf}} {"All files" {*}}}]

if { $path == "" } {
    exit
}

fconfigure stdin -translation binary
set data "8:[read stdin]"

set fd [open $path "w"]
puts -nonewline $fd $data
close $fd

puts $path

ensure_hexf
exec $hexf_path $path

exit
