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

    section "Document info" {
        set rootTag [$root nodeName]
        switch -nocase $rootTag {
            "html" {
                entry "Document type" "HTML"

                entry "<script> count" [llength [$doc getElementsByTagName "script"]]
                entry "<link> count" [llength [$doc getElementsByTagName "link"]]
                entry "<style> count" [llength [$doc getElementsByTagName "style"]]
            }

            "svg" {
                entry "Document type" "SVG"

                entry "Width" [$root getAttribute "width"]
                entry "Height" [$root getAttribute "height"]
                entry "<path> count" [llength [$doc getElementsByTagName "path"]]
            }

            default {
                entry "Document type" "Unknown XML"
            }
        }
    }

    proc traverse {parent} {
        set type [$parent nodeType]
        set name [$parent nodeName]

        switch $type {
            "TEXT_NODE" {
                entry $name [$parent nodeValue]
            }

            "ELEMENT_NODE" {
                set isSection 0
                set value ""

                set attrs [$parent attributes]
                set childNodes [$parent childNodes]

                if {[llength $childNodes] == 1} {
                    set child [lindex $childNodes 0]

                    if {[$child nodeType] == "TEXT_NODE"} {
                        set value [$child nodeValue]
                    } else {
                        set isSection 1
                    }
                } elseif {[llength $childNodes] > 1} {
                    set isSection 1
                }

                if {[llength $attrs]} {
                    set isSection 1
                }

                if { $isSection } {
                    section "<$name>" {
                        sectionvalue $value

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

                        foreach child $childNodes {
                            traverse $child
                        }
                    }
                } else {
                    entry "<$name>" $value
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
