# Protobuf.tcl
# Basic HexFiend template for Google Protocol Buffers wire format.
# Limitations:
# - Does not know field names (only numbers).
# - Cannot distinguish between different types using the same wire type (e.g., int32/uint32/sint32/enum for VARINT).
# - Shows basic interpretation of LEN fields (hex/string attempt); cannot reliably parse submessages or packed repeated fields without schema.
# - Does not handle deprecated Groups (SGROUP/EGROUP) robustly.
#
# https://good.tools/protobuf-decoder
# application/vnd.com.apple.me.mmcs+protobuf
#
# Uses section features:
# .min_version_required = 2.15;

# Set default endianness for fixed-size types (Protobuf uses little-endian)
little_endian

# Procedure to decode ZigZag encoded varint
proc decode_zigzag {value} {
    # Works for both 32 and 64 bit, assuming Tcl's arbitrary precision handles it
    set is_negative [expr {$value & 1}]
    set shifted_value [expr {$value >> 1}]
    if {$is_negative} {
        # For negative n, original encoding was 2*|n| - 1 => value = 2*(-n) - 1
        # => value + 1 = -2n => n = -(value + 1) / 2
        # Using bitwise NOT avoids potential issues with large number division/negation:
        # return [expr {~ $shifted_value}] # This is equivalent
        return [expr {($shifted_value ^ -1)}]
    } else {
        # For positive p, original encoding was 2*p => value = 2*p
        # => p = value / 2
        return $shifted_value
    }
}


# Main procedure to parse a Protobuf message structure up to a certain position
# end_pos: The absolute file offset where parsing should stop for this message/level.
proc parse_proto_message { end_pos } {
    global errorInfo # Make errorInfo accessible for debugging

    while {true} {
        set current_offset [pos]
        if {$current_offset >= $end_pos} {
            if {$current_offset > $end_pos} {
                puts stderr "Warning: Read past expected end offset $end_pos, currently at $current_offset"
                # Optionally move back: goto $end_pos
            }
            break ; # Stop parsing this level
        }

        # Read the Tag (Field Number + Wire Type)
        set tag_start_pos [pos]
        set tag_varint [uleb128]
        set tag_len [expr {[pos] - $tag_start_pos}]

        set wire_type [expr {$tag_varint & 0x07}]
        set field_number [expr {$tag_varint >> 3}]

        # Determine wire type string for display
        set wire_type_str "Unknown ($wire_type)"
        switch $wire_type {
            0 { set wire_type_str "VARINT" }
            1 { set wire_type_str "I64" }
            2 { set wire_type_str "LEN" }
            3 { set wire_type_str "SGROUP" }
            4 { set wire_type_str "EGROUP" }
            5 { set wire_type_str "I32" }
        }

        # Start a section for this field
        section "Field $field_number ($wire_type_str)" {
            # Use -collapsed for LEN types as they can be large/recursive
            if {$wire_type_str == "LEN"} {
                sectioncollapse
            }


            # Display Tag details within the section
            entry "Tag (Varint)" $tag_varint $tag_len $tag_start_pos
            entry "Field Number" $field_number
            entry "Wire Type" "$wire_type ($wire_type_str)"

            # Process Value based on wire_type
            switch $wire_type_str {
                VARINT {
                    set value_start_pos [pos]
                    set value [uleb128]
                    set value_len [expr {[pos] - $value_start_pos}]

                    # Display different interpretations
                    entry "Value (Varint, Unsigned)" $value $value_len $value_start_pos
                    entry "Value (Varint, Hex)" [format "0x%X" $value] $value_len $value_start_pos

                    # Show potential ZigZag interpretation
                    set zigzag_decoded [decode_zigzag $value]
                    entry "Value (Potential sint32/sint64 ZigZag Decoded)" $zigzag_decoded $value_len $value_start_pos

                    sectionvalue "$value (Unsigned)"
                }
                I64 {
                    set value_start_pos [pos]
                    uint64 -hex "Value (uint64, hex)"
                    goto $value_start_pos
                    int64 "Value (int64, signed)"
                    goto $value_start_pos
                    double "Value (double)"
                    # Set section value (use hex as a common representation)
                    goto $value_start_pos
                    set hex_val [hex 8 ""]
                    sectionvalue "0x$hex_val"
                }
                LEN {
                    set len_start_pos [pos]
                    set len [uleb128]
                    entry "Length" $len [expr {[pos] - $len_start_pos}] $len_start_pos

                    set data_start_pos [pos]
                    sectionvalue "Length = $len bytes"

                    if {$len < 0} {
                        entry "Error" "Invalid negative length ($len) encountered"
                        error "Invalid negative length $len for LEN field $field_number"
                    } elseif {$len == 0} {
                        entry "Payload" "(Empty)" 0 $data_start_pos
                    } elseif {[expr $data_start_pos + $len] > [len]} {
                        entry "Error" "Length $len exceeds file boundary ([len])"
                        # Display what we can
                        hex [expr {[len] - $data_start_pos}] "Partial Payload (Hex)"
                        goto [len] ; # Move to end
                        error "LEN field $field_number length $len exceeds file size"
                    } else {
                        # Present multiple interpretations of the payload
                        section "Payload Data ($len bytes)" {
                            # Try as UTF-8 String
                            # Use catch as it might not be valid UTF-8
                            if {[catch {str $len "utf8" "Potential String (UTF-8)"} msg]} {}

                            goto $data_start_pos ; # Go back before reading hex
                            bytes $len "Bytes"

                            # Advanced: Add a button/option here to attempt recursive parse?
                            # entry "Action" "[Try Parse as Submessage]" ...
                            # For now, we don't automatically recurse as we lack schema.
                        }
                        goto [expr $data_start_pos + $len] ; # Move pointer past the data
                    }
                }
                SGROUP {
                    sectionname "Field $field_number (Start Group)"
                    entry "Note" "Deprecated Start Group marker. Parsing within groups not fully implemented."
                    # Correct handling would require parsing until a matching EGROUP tag.
                    # This basic template doesn't track group nesting state.
                }
                EGROUP {
                    sectionname "Field $field_number (End Group)"
                    entry "Note" "Deprecated End Group marker."
                    # In correct parsing, this should only be encountered when expected.
                    # If found unexpectedly, it might indicate an error or end of group data.
                }
                I32 {
                    set value_start_pos [pos]
                    uint32 -hex "Value (uint32, hex)"
                    goto $value_start_pos
                    int32 "Value (int32, signed)"
                    goto $value_start_pos
                    float "Value (float)"
                    # Set section value
                    goto $value_start_pos
                    set hex_val [hex 4 ""]
                    sectionvalue "0x$hex_val"
                }
                default {
                    entry "Error" "Unknown Wire Type: $wire_type"
                    # Cannot proceed reliably, stop parsing this level
                    error "Aborting due to unknown wire type $wire_type at offset [pos]"
                }
            }
        }
    }
}

# Wrap the main parsing logic in a catch block for better error reporting
if {[catch {
    # Parse the entire file as a top-level message
    parse_proto_message [len]
} result options]} {
    # An error occurred during parsing
    set err_code [dict get $options -errorcode]
    set err_info [dict get $options -errorinfo] ;# Stack trace

    puts stderr "-----------------------------------------------------"
    puts stderr "Protobuf Template Error Occurred!"
    puts stderr "Message: $result"
    puts stderr "Error Code: $err_code"
    puts stderr "Current File Offset: [pos]"
    puts stderr "Stack Trace:\n$err_info"
    puts stderr "-----------------------------------------------------"

    # Display error in the UI as well
    section -collapsed "PARSING ERROR" {
        entry "Message" $result
        entry "Offset" [pos]
        entry "Details" "See Hex Fiend Console log for stack trace"
        # You could try showing parts of err_info, but it can be long
    }
} else {
    # Parsing completed (potentially with warnings printed to stderr)
    # Check if we ended exactly at the end of the file
    if {[pos] != [len]} {
        puts stderr "Warning: Parsing finished at offset [pos], but file length is [len]."
        section "Remaining Data" {
            bytes eof "Unparsed Trailing Data"
        }
    } else {
        # Add a small confirmation entry maybe
        # entry "Status" "Parsing Complete" 0 [len]
    }
}
