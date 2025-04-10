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

        section -collapsed "<$name>" {
            set attrs [$parent attributes]
            if {[llength $attrs]} {
                section -collapsed "Attributes" {
                    foreach attr $attrs {
                        if [catch {
                            entry $attr [$parent getAttribute $attr]
                        }] {
                            report "Invalid attribute: $attr"
                        }
                    }
                }
            }

            foreach child [$parent childNodes] {
                traverse $child
            }
        }
    }

    traverse $root
}
