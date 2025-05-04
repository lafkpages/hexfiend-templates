# Apple Shortcut
#
# https://www.reddit.com/r/shortcuts/comments/10e997p/shortcuts_file_format/
# https://zachary7829.github.io/blog/shortcuts/fileformat
# https://theapplewiki.com/wiki/Apple_Encrypted_Archive
#
# .types = ( com.apple.shortcut, shortcut );

include "Utility/General.tcl"

requires 0 "4145413100000000"

set ::embedded_plist 1
include "hexfiend-templates/Apple Property List.tcl"

little_endian

main_guard {
    section "Apple Encrypted Archive Header" {
        ascii 4 "Magic"

        set profile_id [uint24]
        switch $profile_id {
            0 {
                set profile_id_str "No encryption, Signed"
                set prologue_signature_size 128
                set encryption_data_size 32
            }
            1 {
                set profile_id_str "Symmetric key encryption"
                set prologue_signature_size 0
                set encryption_data_size 0
            }
            2 {
                set profile_id_str "Symmetric key encryption, Signed"
                set prologue_signature_size 160
                set encryption_data_size 0
            }
            3 {
                set profile_id_str "ECDHE encryption"
                set prologue_signature_size 0
                set encryption_data_size 65
            }
            4 {
                set profile_id_str "ECDHE encryption, Signed"
                set prologue_signature_size 160
                set encryption_data_size 65
            }
            5 {
                set profile_id_str "scrypt encryption (password based)"
                set prologue_signature_size 0
                set encryption_data_size 0
            }
            default {
                set profile_id_str "Invalid profile ID"
            }
        }
        entry "Profile ID" "$profile_id_str ($profile_id)" 3 4

        set scrypt_hardness [uint8]
        entry "Scrypt hardness" $scrypt_hardness 1 7

        set auth_data_size [uint32]
        entry "Auth data size" $auth_data_size 4 8
    }

    section -collapsed "Auth data" {
        big_endian
        plist 12 $auth_data_size
        little_endian
    }

    if { $prologue_signature_size } {
        bytes $prologue_signature_size "Prologue signature"
    }

    if { $encryption_data_size } {
        bytes $encryption_data_size "Encryption data"
    }

    bytes 32 "Salt"
    bytes 32 "Root HMAC"
    section "Root header" {
        sentry 48 {
            set raw_size [uint64]
            move -8
            entry "Raw size" $raw_size 8
            move 8

            set container_size [uint64]
            move -8
            entry "Container size" $container_size 8
            move 8

            set segment_size [uint32]
            move -4
            entry "Segment size" "[human_size $segment_size] / $segment_size bytes" 4
            move 4

            set segments_per_cluster [uint32]
            move -4
            entry "Segments per cluster" $segments_per_cluster 4
            move 4

            set compression_algorithm [ascii 1]
            switch $compression_algorithm {
                "-" {
                    set compression_algorithm_str "No compression"
                }
                "4" {
                    set compression_algorithm_str "LZ4"
                }
                "z" {
                    set compression_algorithm_str "zlib (level 5)"
                }
                "x" {
                    set compression_algorithm_str "LZMA (preset 6)"
                }
                "b" {
                    set compression_algorithm_str "LZBITMAP"
                }
                "e" {
                    set compression_algorithm_str "LZFSE"
                }
                "f" {
                    set compression_algorithm_str "LZVN"
                }
                default {
                    set compression_algorithm_str "Unknown ($compression_algorithm)"
                }
            }
            move -1
            entry "Compression algorithm" "$compression_algorithm_str" 1
            move 1

            set checksum_algorithm [uint8]
            switch $checksum_algorithm {
                0 {
                    set checksum_algorithm_str "No checksum"
                }
                1 {
                    set checksum_algorithm_str "MurMurHash2"
                }
                2 {
                    set checksum_algorithm_str "SHA-256"
                }
                default {
                    set checksum_algorithm_str "Unknown ($checksum_algorithm)"
                }
            }
            move -1
            entry "Checksum algorithm" "$checksum_algorithm_str" 1
            move 1

            bytes 22 "Padding"
            # TODO: check that the padding is all zeroes
        }
    }
    bytes 32 "First cluster HMAC"
}