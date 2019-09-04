	processor 6502

;; ------------------------------------------------------------------

	seg.u data
	org $80

puts_ptr
	ds 2

debug_ptr
	ds 2

memcmp_a_ptr
	ds 2

memcmp_b_ptr
	ds 2

memcmp_length
	ds 2

hexdump_ptr
	ds 2

disk_address
	ds 2

scanf_word_ptr
	ds 2

scanf_word_result
	ds 2

scanf_byte_ptr
	ds 2

scanf_byte_result
	ds 1

;; ------------------------------------------------------------------

	seg.u hidata
	org $100

disk_sector_data
	ds $40

;; ------------------------------------------------------------------

	seg cdata
	org $4000

CR	equ $0a, $0d

hexdigits
	.byte "0123456789abcdef"

trace_disk_read_sector
	.byte "disk_read_sector", $00

;; ------------------------------------------------------------------

	seg code
	org $8000

        ;; ----------------------------------------------------------

	mac	load_address
	lda #<[{2}]
	sta [{1}]
	lda #>[{2}]
	sta [{1}] + 1
	endm

	mac     inc16
	inc     {1}
	bne 	.1
	inc     {1}+1
.1
	endm

	mac     dec16
	lda	{1}
	cmp 	#0
	bne	.1
	dec     {1}+1
.1
	dec     {1}
	endm


        ;; ----------------------------------------------------------

_debug  subroutine
	rts

        ;; ----------------------------------------------------------

	mac	debug_trace
	load_address debug_ptr, [{1}]
	jsr _debug
	endm

        ;; ----------------------------------------------------------

memcmp  subroutine
.loop
	lda memcmp_length
	cmp #0
	bne .1
	lda memcmp_length+1
	cmp #0
	bne .1

	lda #0
	rts
.1
	;ldx #0
	;lda (memcmp_a_ptr,X)
	;jsr _putc

	;ldx #0
	;lda (memcmp_b_ptr,X)
	;jsr _putc

	ldx #0
	lda (memcmp_a_ptr,X)
	cmp (memcmp_b_ptr,X)
	beq .2

	lda #1
	rts

.2
	inc16 memcmp_a_ptr
	inc16 memcmp_b_ptr
	dec16 memcmp_length
	jmp .loop

        ;; ==========================================================

DISK_STATUS_REGISTER equ $F200
DISK_COMMAND_REGISTER equ $F201
DISK_ADDRESS_LOW_REGISTER equ $F210
DISK_ADDRESS_HIGH_REGISTER equ $F211
DISK_BUFFER_LOW_REGISTER equ $F220
DISK_BUFFER_HIGH_REGISTER equ $F221

        ;; ----------------------------------------------------------

disk_read_sector	subroutine
	debug_trace trace_disk_read_sector

	lda disk_address
	sta DISK_ADDRESS_LOW_REGISTER
	lda disk_address + 1
	sta DISK_ADDRESS_HIGH_REGISTER

	lda #<disk_sector_data
	sta DISK_BUFFER_LOW_REGISTER
	lda #>disk_sector_data
	sta DISK_BUFFER_HIGH_REGISTER

	lda #$81
	sta DISK_COMMAND_REGISTER
	rts

        ;; ----------------------------------------------------------

	seg.u data

disk_scan_prefix
	ds 2

disk_scan_prefix_length
	ds 2

disk_scan_index
	ds 1

	seg code

disk_scan_for_path
	subroutine

	lda #00
	sta disk_scan_index

.loop
	lda disk_scan_index
	sta disk_address
	lda #0
	sta disk_address+1
	jsr disk_read_sector

	;load_address hexdump_ptr, disk_sector_data
	;jsr print_hexline

	lda disk_scan_prefix
	sta memcmp_a_ptr
	lda disk_scan_prefix+1
	sta memcmp_a_ptr+1
	load_address memcmp_b_ptr, disk_sector_data
	lda disk_scan_prefix_length
	sta memcmp_length
	lda disk_scan_prefix_length+1
	sta memcmp_length+1

	;load_address hexdump_ptr, disk_sector_data
	;jsr print_hexline

	jsr memcmp
	cmp #0
	beq .found

	inc disk_scan_index
	lda disk_scan_index
	cmp #$40
	bne .loop

	lda #1
	rts

.found
	lda #0
	rts


        ;; ==========================================================

CONSOLE_IN  equ $F000
CONSOLE_OUT equ $F001

        ;; ----------------------------------------------------------

_getc	subroutine
	lda CONSOLE_IN
	rts

        ;; ----------------------------------------------------------

_putc	subroutine
	sta CONSOLE_OUT
        rts

        ;; ----------------------------------------------------------

_puts	subroutine
.loop
        ldx #$00
	lda (puts_ptr,X)
	sta CONSOLE_OUT
	cmp #0
	beq .done

	inc16 puts_ptr
	jmp .loop

.done
	rts

        ;; ----------------------------------------------------------

	mac	puts
        load_address puts_ptr, [{1}]
	jsr _puts
	endm

        ;; ----------------------------------------------------------

convert_nibble
	subroutine
	cmp #'0
	bmi .invalid
	cmp #$40
	bmi .digit

	cmp #'A
	bmi .invalid
	cmp #'G
	bmi .alpha

	cmp #'a
	bmi .invalid
	cmp #'g
	bmi .alpha

.invalid
	lda #$ff
	rts

.alpha
	and #$0f
	clc
	adc #9
	rts

.digit
	and #$0f
	rts

scanf_word
	subroutine
	ldx #0
	lda (scanf_word_ptr),X

	jsr convert_nibble
	cmp #$ff
	beq .invalid

	asl
	asl
	asl
	asl
	sta scanf_word_result+1

	ldy #1
	lda (scanf_word_ptr),Y

	jsr convert_nibble
	cmp #$ff
	beq .invalid

	ora scanf_word_result+1
	sta scanf_word_result+1

	ldy #2
	lda (scanf_word_ptr),Y

	jsr convert_nibble
	cmp #$ff
	beq .invalid

	asl
	asl
	asl
	asl
	sta scanf_word_result

	ldy #3
	lda (scanf_word_ptr),Y

	jsr convert_nibble
	cmp #$ff
	beq .invalid

	ora scanf_word_result
	sta scanf_word_result

	lda #0
	rts

.invalid
	lda #$ff
	rts

        ;; ----------------------------------------------------------

scanf_byte
	subroutine
	ldx #0
	lda (scanf_byte_ptr),X

	jsr convert_nibble
	cmp #$ff
	beq .invalid

	asl
	asl
	asl
	asl
	sta scanf_byte_result

	ldy #1
	lda (scanf_byte_ptr),Y

	jsr convert_nibble
	cmp #$ff
	beq .invalid

	ora scanf_byte_result
	sta scanf_byte_result

	lda #0
	rts

.invalid
	lda #$ff
	rts

        ;; ----------------------------------------------------------

print_hex_byte
	subroutine
	tax

	lsr
	lsr
	lsr
	lsr
	tay
	lda hexdigits,Y
	jsr _putc

	txa
	and #$f
	tay
	lda hexdigits,Y
	jsr _putc

	rts

        ;; ----------------------------------------------------------

print_newline
	subroutine
	lda #$0a
	jsr _putc
	lda #$0d
	jsr _putc
	rts

        ;; ----------------------------------------------------------

print_hexline
	subroutine
	ldy #0

.loop
	tya
	pha
	lda (hexdump_ptr),Y
	jsr print_hex_byte
	lda #$20
	jsr _putc
	pla
	tay

	iny
	cpy #$10
	bne .loop

.done
        jsr print_newline
	rts

        ;; ==========================================================

	seg cdata

fw_banner
	.byte "Starting ArkOS...", 0

fw_version_label
	.byte "Firmware version: ", 0

fw_version
	.byte "1.1.B", 0

hw_version_label
	.byte "Hardware version: ", 0

memory_map_label
	.byte "Memory map:", CR, 0

memory_map_0
	.byte "  $0000:$00FF - RAM", CR, 0

memory_map_1
	.byte "  $0100:$01FF - RAM (stack)", CR, 0

memory_map_2
	.byte "  $0200:$1FFF - RAM", CR, 0

memory_map_3
	.byte "  $4000:$EFFF - PROM", CR, 0

memory_map_4
	.byte "  $F000:$FF00 - MMIO", CR, 0

memory_map_5
	.byte "  $FF00:$FFFF - PROM", CR, 0


	seg code

HW_VERSION_STRING equ $F400

        ;; ----------------------------------------------------------

print_memory_map
	subroutine
	puts memory_map_label
	puts memory_map_0
	puts memory_map_1
	puts memory_map_2
	puts memory_map_3
	puts memory_map_4
	puts memory_map_5
	rts

        ;; ----------------------------------------------------------

init	subroutine
	puts fw_banner
	jsr print_newline
	puts hw_version_label
	lda #$00
	sta puts_ptr
	lda #$F4
	sta puts_ptr + 1
	jsr _puts
	jsr print_newline
	puts fw_version_label
	puts fw_version
	jsr print_newline
	jsr print_memory_map
	rts

        ;; ----------------------------------------------------------

	seg.u data

print_sector_sector
	ds 2

	seg code

print_sector_string
	subroutine

	lda print_sector_sector
	sta disk_address
	lda print_sector_sector + 1
	sta disk_address + 1
	jsr disk_read_sector

        ldx #0
.loop
	lda disk_sector_data,X
	cmp #0
	beq .done
	jsr _putc
	inx
	cpx #$40
	bne .loop

.done
	rts

        ;; ----------------------------------------------------------

	seg.u data

print_file_count
	ds 2

print_file_sector
	ds 2

	seg code

print_file_string
	subroutine
	ldx #$30
	lda disk_sector_data,X
	sta print_file_sector
	inx
	lda disk_sector_data,X
	sta print_file_sector+1
	inx
	lda disk_sector_data,X
	sta print_file_count
	inx
	lda disk_sector_data,X
	sta print_file_count+1

.loop
	lda print_file_count
	cmp #0
	bne .1
	lda print_file_count + 1
	cmp #0
	beq .done
.1
	lda print_file_sector
	sta print_sector_sector
	lda print_file_sector + 1
	sta print_sector_sector + 1
	jsr print_sector_string

	dec16 print_file_count
	inc16 print_file_sector
	jmp .loop

.done
	rts

        ;; ----------------------------------------------------------

	seg cdata

motd_file_path
	.byte "/etc/motd", 0

motd_file_path_length equ $07

motd_lookup_failed
	.byte "ERROR: failed to find /etc/motd", CR, 0

motd_lookup_succeeded
	.byte "Found /etc/motd!", CR, 0

mail_file_path
	.byte "/var/mail/spool/atredis", 0

mail_file_path_length equ $17

mail_lookup_begin
	.byte "Checking mail for user atredis...", CR, 0

mail_lookup_succeeded
	.byte "Found mail!", CR, CR, 0

mail_lookup_failed
	.byte "No mail.", CR, 0

	seg code

print_motd
	subroutine
	load_address disk_scan_prefix, motd_file_path
	lda #motd_file_path_length
	sta disk_scan_prefix_length
	lda #0
	sta disk_scan_prefix_length + 1
	jsr disk_scan_for_path

        cmp #0
        bne .failed

        puts motd_lookup_succeeded
	jsr print_file_string
	rts

.failed
	puts motd_lookup_failed
	rts

        ;; ----------------------------------------------------------

print_mail
	subroutine

	puts mail_lookup_begin

	load_address disk_scan_prefix, mail_file_path
	lda #mail_file_path_length
	sta disk_scan_prefix_length
	lda #0
	sta disk_scan_prefix_length + 1
	jsr disk_scan_for_path

        cmp #0
        bne .failed

	puts mail_lookup_succeeded
	jsr print_file_string
	rts

.failed
	puts mail_lookup_failed
	rts

        ;; ----------------------------------------------------------

	seg cdata

cli_prompt
	.byte "arkos> ", 0

cli_invalid_command
	.byte "Invalid command", CR, 0

cli_command_help_prefix
	.byte "help"

cli_command_help_prefix_length equ $04

cli_command_read_prefix
	.byte "read "

cli_command_read_prefix_length equ $05

cli_command_write_prefix
	.byte "write "

cli_command_write_prefix_length equ $06

cli_command_call_prefix
	.byte "call "

cli_command_call_prefix_length equ $05

cli_help_0
	.byte CR
	.byte "Commands:", CR
	.byte "  help", CR
	.byte "    This message", CR
	.byte "  read", CR
	.byte "    'read F400' reads the byte at $F400", CR
	;; .byte "  write", CR
	;; .byte "    'write 0004 41' writes an $41 to $0004", CR
	.byte 0

        seg.u data

cli_buffer_index
	ds 1

        seg.u hidata

cli_buffer
	ds $40

cli_call_tramp
	ds $10

        seg code

cli_read_command
	subroutine
	lda #0
	sta cli_buffer_index

.loop
	jsr _getc
	cmp #$0a
	beq .done

	ldx cli_buffer_index
	sta cli_buffer,X
	inx
	stx cli_buffer_index
	cpx #$3f
	bne .loop

.done
	ldx cli_buffer_index
	lda #0
	sta cli_buffer,X
	rts

        ;; ----------------------------------------------------------

cli_handle_command_help
	subroutine
	load_address memcmp_a_ptr, cli_command_help_prefix
	load_address memcmp_b_ptr, cli_buffer
	lda #cli_command_help_prefix_length
	sta memcmp_length
	lda #0
	sta memcmp_length+1
	jsr memcmp

	cmp #0
	beq .found

	lda #0
	rts

.found
	puts cli_help_0
	lda #1
	rts

cli_handle_command_read
	subroutine
	load_address memcmp_a_ptr, cli_command_read_prefix
	load_address memcmp_b_ptr, cli_buffer
	lda #cli_command_read_prefix_length
	sta memcmp_length
	lda #0
	sta memcmp_length+1
	jsr memcmp

	cmp #0
	beq .found

	lda #0
	rts

.found
	load_address scanf_word_ptr, cli_buffer
	inc16 scanf_word_ptr
	inc16 scanf_word_ptr
	inc16 scanf_word_ptr
	inc16 scanf_word_ptr
	inc16 scanf_word_ptr
	jsr scanf_word

	lda #'$
	jsr _putc
	lda scanf_word_result+1
	jsr print_hex_byte
	lda scanf_word_result
	jsr print_hex_byte
	lda #$20
	jsr _putc
	lda #'=
	jsr _putc
	lda #$20
	jsr _putc
	lda #'$
	jsr _putc
	ldx #0
	lda (scanf_word_result,X)
	jsr print_hex_byte
	jsr print_newline

	lda #1
	rts

cli_handle_command_write
	subroutine
	load_address memcmp_a_ptr, cli_command_write_prefix
	load_address memcmp_b_ptr, cli_buffer
	lda #cli_command_write_prefix_length
	sta memcmp_length
	lda #0
	sta memcmp_length+1
	jsr memcmp

	cmp #0
	beq .found

	lda #0
	rts

.found
	load_address scanf_word_ptr, cli_buffer
	inc16 scanf_word_ptr
	inc16 scanf_word_ptr
	inc16 scanf_word_ptr
	inc16 scanf_word_ptr
	inc16 scanf_word_ptr
	inc16 scanf_word_ptr
	lda scanf_word_ptr
	sta scanf_byte_ptr
	lda scanf_word_ptr+1
	sta scanf_byte_ptr+1
	inc16 scanf_byte_ptr
	inc16 scanf_byte_ptr
	inc16 scanf_byte_ptr
	inc16 scanf_byte_ptr
	inc16 scanf_byte_ptr

	jsr scanf_word

	jsr scanf_byte

	lda #'$
	jsr _putc
	lda scanf_word_result+1
	jsr print_hex_byte
	lda scanf_word_result
	jsr print_hex_byte
	lda #$20
	jsr _putc
	lda #':
	jsr _putc
	lda #'=
	jsr _putc
	lda #$20
	jsr _putc
	lda #'$
	jsr _putc
	lda scanf_byte_result
	jsr print_hex_byte
	jsr print_newline

	ldx #0
	lda scanf_byte_result
	sta (scanf_word_result,X)

	lda #1
	rts

cli_handle_command_call
	subroutine
	load_address memcmp_a_ptr, cli_command_call_prefix
	load_address memcmp_b_ptr, cli_buffer
	lda #cli_command_call_prefix_length
	sta memcmp_length
	lda #0
	sta memcmp_length+1
	jsr memcmp

	cmp #0
	beq .found

	lda #0
	rts

.found
	load_address scanf_word_ptr, cli_buffer
	inc16 scanf_word_ptr
	inc16 scanf_word_ptr
	inc16 scanf_word_ptr
	inc16 scanf_word_ptr
	inc16 scanf_word_ptr
	jsr scanf_word

	lda #'j
	jsr _putc
	lda #'s
	jsr _putc
	lda #'r
	jsr _putc
	lda #$20
	jsr _putc
	lda #'$
	jsr _putc
	lda scanf_word_result+1
	jsr print_hex_byte
	lda scanf_word_result
	jsr print_hex_byte
	jsr print_newline

	ldx #0
	lda #$20 ; JSR
	sta cli_call_tramp,X
	inx
	lda scanf_word_result
	sta cli_call_tramp,X
	inx
	lda scanf_word_result+1
	sta cli_call_tramp,X
	inx
	lda #$60 ; RTS
	sta cli_call_tramp,X
	inx

	jsr cli_call_tramp

	lda #1
	rts


cli_handle_command
	subroutine

	jsr cli_handle_command_help
	cmp #0
	bne .done

	jsr cli_handle_command_read
	cmp #0
	bne .done

	jsr cli_handle_command_write
	cmp #0
	bne .done

	jsr cli_handle_command_call
	cmp #0
	bne .done

	puts cli_invalid_command
	lda #1
.done
	rts

        ;; ----------------------------------------------------------

cli	subroutine

.loop
	jsr print_newline
	puts cli_prompt
	jsr cli_read_command
	; puts cli_buffer
	jsr cli_handle_command
	cmp #$ff
	bne .loop

	rts

        ;; ==========================================================

reset	subroutine

	jsr init
	jsr print_motd
	jsr print_mail
	jsr cli

.loop
	jmp .loop
	rts


nmi	rti

irq	rti

;; ------------------------------------------------------------------

	org $FFFA
	.word reset
	.word reset
	.word reset
