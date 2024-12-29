# .hidden = true;

proc eol {} {
    set eol 0
    while {[uint8] ne 10} {
        incr eol
    }
    move -$eol
    move -1
    return $eol
}
