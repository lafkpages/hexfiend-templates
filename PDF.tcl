# .types = ( com.adobe.pdf, pdf );

include "Utility/General.tcl"
include "hexfiend-templates/util.tcl"

main_guard {
    requires 0 "25 50 44 46 2D"
    goto 5
    ascii [eol] "PDF version"
    move 1
}