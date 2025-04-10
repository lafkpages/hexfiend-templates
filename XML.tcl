# .types = ( public.xml, xml, public.html, html );

include "Utility/General.tcl"

# https://wiki.tcl-lang.org/page/A+tDOM+Tutorial
package require tdom

variable xml
variable doc
variable root

main_guard {
    set xml [bytes [len]]
    set doc [dom parse $xml]
    set root [$doc documentElement]

    proc traverse {parent} {
        set type [$parent nodeType]
        set name [$parent nodeName]

        if {$type != "ELEMENT_NODE"} {
            puts "$parent is a $type node named $name"
            return
        }

        section "<$name>" {
            # if {[llength [$parent attributes]]} {
            #     puts "attributes: [join [$parent attributes] ", "]"
            # }

            foreach child [$parent childNodes] {
                traverse $child
            }
        }
    }

    traverse $root
}