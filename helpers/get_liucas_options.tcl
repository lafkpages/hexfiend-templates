# I wrote this but ended up not needing it. Leaving it here in case it's
# helpful later.
#
# .hidden = true;

set helpers_dir [file dirname [info script]]
source [file join $helpers_dir "util.tcl"]

package require Tk

set byte_length_bytes 1

wm state . withdrawn

# Create dialog window
set dlg .dialog
toplevel $dlg

# Create entry field
label $dlg.entry_label -text "Byte length bytes"
ttk::combobox $dlg.entry -textvariable byte_length_bytes -values {1 2 4} -state readonly
grid $dlg.entry_label -row 0 -column 0 -padx {10 5} -pady {10 5} -sticky w
grid $dlg.entry -row 0 -column 1 -padx {5 10} -pady {10 5} -sticky ew

# Create buttons
button $dlg.ok -text "OK" -command [list set waiting($dlg) 1]
button $dlg.cancel -text "Cancel" -command [list set waiting($dlg) 0]
grid $dlg.ok -row 1 -column 0 -padx {10 5} -pady {0 10} -sticky ew
grid $dlg.cancel -row 1 -column 1 -padx {5 10} -pady {0 10} -sticky ew

# Keep widgets responsive when resizing
grid columnconfigure $dlg 0 -weight 0
grid columnconfigure $dlg 1 -weight 1

bind $dlg <Return> [list set waiting($dlg) 1]
bind $dlg <Escape> [list set waiting($dlg) 0]

# Trapping a window manager message; slightly different to normal events for historical reasons
# https://stackoverflow.com/a/39611348/15584743
wm protocol $dlg WM_DELETE_WINDOW [list set waiting($dlg) 0]

vwait waiting($dlg)
if { $waiting($dlg) } {
    puts -nonewline $byte_length_bytes
}
exit

# Run with: [exec $wish_path [file join $helpers_dir "get_liucas_options.tcl"]]
