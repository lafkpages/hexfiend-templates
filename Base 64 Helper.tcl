# .types = ( base64 );

include "Utility/General.tcl"
include "hexfiend-templates/utils/util.tcl"

main_guard {
    ensure_wish

    set raw_data [bytes eof]

    exec $wish_path [file join $util_dir "save_base64.tcl"] << $raw_data &
}
