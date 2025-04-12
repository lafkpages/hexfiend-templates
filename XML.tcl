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

        switch $type {
            "TEXT_NODE" {
                entry $name [$parent nodeValue]
            }

            "ELEMENT_NODE" {
                set isSection 0

                set attrs [$parent attributes]
                if {[$parent hasChildNodes] || [llength $attrs]} {
                    set isSection 1
                }

                if { $isSection } {
                    section "<$name>" {
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
                } else {
                    entry "<$name>" ""
                }
            }

            default {
                entry "Unknown node type" $type
                return
            }
        }
    }


    traverse $root
}
