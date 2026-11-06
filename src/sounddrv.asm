; PC-speaker and Tandy SN76489 timer sequencer, linked into SoundDrv by SOUNDDRV.OBJ.
; Owns voice blocks, tune streams, envelopes and modulation tables in CODE.
; Pascal far entries install/remove INT 8, load tunes and control the output gate.
; Four voices per device are stepped; the speaker uses the first active voice.
; The displaced BIOS handler runs every thirteenth tick.

CODE    SEGMENT BYTE PUBLIC 'CODE'
        ASSUME  CS:CODE, DS:CODE
        PUBLIC  InstallSoundTimer, UninstallSoundTimer
        PUBLIC  ProgramSpeakerVoices, ProgramTandyVoices, SetSoundOutputEnabled

; ---------------------------------------------------------------------------
; Voice state. SSET writes fields by offset; voice_step advances them
; on each timer interrupt.
; ---------------------------------------------------------------------------
VOICE   STRUC
vfDuration      dw      0       ; ticks until the sequencer next steps this voice
vfStream        dw      0       ; stream pointer; 0 = the voice is idle
vfPeriod        dw      0       ; pitch accumulator
vfPeriodAdd     dw      0       ; added to vfPeriod each tick -- a pitch slide
vfOutPeriod     dw      0       ; vfPeriod plus the LFO; this is what the chip gets
vfLevel         dw      0       ; output level
vfLevelAdd      dw      0       ; added to vfLevel each tick
vfTempo         dw      0       ; low byte scales duration; 0 or 1 leaves it unchanged
vfReleaseLead   dw      0       ; release lead; unused
vfTranspose     dw      0       ; added to a note's pitch before the octave reduction
vfGateLen       dw      0       ; when it expires the envelope restarts at its 5th pair
vfEnvBase       dw      0       ; base of this voice's (value,ticks) envelope list
vfEnvPos        dw      0       ; byte offset into that list
vfEnvWait       dw      0       ; ticks left in the current envelope segment
vfLfoTable      dw      0       ; base pointer into the LFO samples
vfLfoPhase      dw      0       ; LFO phase accumulator
vfLfoRate       dw      0       ; added to vfLfoPhase each tick
vfLfoDepth      dw      0       ; signed multiplier on the waveform sample
vfLfoWrap       dw      0       ; vfLfoPhase wraps here
vfLoopCounterA  dw      0       ; SLOOP counter
vfLoopCounterB  dw      0       ; SLOOP counter for a loop nested inside the first
                dw      3 dup(0)        ; Reserved words, cleared with the voice state.
VOICE   ENDS

; ---------------------------------------------------------------------------
; Note tables: one octave per device. seq_note selects a semitone,
; then shifts its period right by the octave number.
; ---------------------------------------------------------------------------
; PC-speaker divisors for PIT channel 2, starting at C1.
; Nominal frequencies below assume a 1193182 Hz PIT input.
spkC    equ 8E84h    ; C1    32.704 Hz
spkCS   equ 8684h    ; C#1   34.649 Hz
spkD    equ 7EF7h    ; D1    36.710 Hz
spkDS   equ 77D7h    ; D#1   38.892 Hz
spkE    equ 714Fh    ; E1    41.134 Hz; 2.9 cents flat
spkF    equ 6AC4h    ; F1    43.655 Hz
spkFS   equ 64C6h    ; F#1   46.251 Hz
spkG    equ 5F1Eh    ; G1    49.001 Hz
spkGS   equ 59C7h    ; G#1   51.916 Hz
spkA    equ 54BDh    ; A1    55.003 Hz
spkAS   equ 4FFCh    ; A#1   58.272 Hz
spkB    equ 4B7Eh    ; B1    61.740 Hz

; Tandy SN76489 periods with nominal note names starting at A2.
; Each 10-bit period is shifted left by six; tick_tandy shifts it back before output.
snA2    equ 0FFC0h   ; A2  n=1023
snAS2   equ 0F140h   ; A#2 n=965
snB2    equ 0E3C0h   ; B2  n=911
snC3    equ 0D700h   ; C3  n=860
snCS3   equ 0CB40h   ; C#3 n=813
snD3    equ 0BF80h   ; D3  n=766
snDS3   equ 0B4C0h   ; D#3 n=723
snE3    equ 0AA80h   ; E3  n=682
snF3    equ 0A100h   ; F3  n=644
snFS3   equ 9800h    ; F#3 n=608
snG3    equ 8F80h    ; G3  n=574
snGS3   equ 8740h    ; G#3 n=541

; ---------------------------------------------------------------------------
; Driver state.  The ISR and the voice writers reach all of it with DS = CODE.
; ---------------------------------------------------------------------------
divCount        db      13              ; ticks left before the next BIOS INT 8 chain
seqBusy         db      0               ; nonzero skips ISR sequencing during voice updates
voiceLeft       db      0               ; voices still to visit this pass, 4 down to 1
blockSize       db      SIZE VOICE      ; seq_note multiplies a voice index by it
exitCount       dw      0               ; Ticks until forced shutdown; zero disables the countdown.

; Shutdown message with bit 7 set in every byte. The timer handler
; clears that bit before displaying the first 33 bytes.
exitMsg         db      0D2h,0F5h,0EEh,0ADh,0F4h,0E9h,0EDh,0E5h,0A0h,0A0h,0C5h,0F2h,0F2h,0EFh,0F2h,0A0h
                db      0B2h,0B0h,0B9h,0A0h,0E1h,0F4h,0A0h,0B0h,0C2h,0C1h,0C4h,0BAh,0B0h,0B0h,0B3h,0B8h
                db      08Ah,08Dh

curTune         dw      0               ; tune id loaded; 0 = silent
seqVoice        dw      0               ; the voice block seq_proc is running
voiceBase       dw      0               ; block array of the device being ticked
freqBase        dw      0               ; note table of the device being ticked
seqRet          dw      0               ; the stream pointer SCALL saved -- one level only
voiceTune       db      0,0,0,0         ; tune id per voice; seq_end clears a voice's entry
                                        ;   when that voice runs out of stream
outputOn        db      1               ; zero mutes output while the sequencers keep running

; Duration table: 3:4 pairs double at each step. Notes carry explicit durations,
; so nothing reads this table.
noteLen         db      000h,000h,000h,002h,000h,003h,004h,000h,006h,008h,000h,00Ch,010h,000h,018h,020h
                db      000h,030h,040h

; Sequencer command dispatch for stream bytes 0FAh through 0FFh, in that order.
cmdTable        dw      seq_c_reset, seq_c_ret, seq_c_call
                dw      seq_c_clear, seq_c_loop, seq_c_set

; Four PC-speaker voices, cleared when a tune starts.
spkrBlocks      VOICE   <>
                VOICE   <>
                VOICE   <>
                VOICE   <>

; Four unused voice blocks reserved after the active voices.
spkrSpare       VOICE   <>
                VOICE   <>
                VOICE   <>
                VOICE   <>

spkrFreq        dw      spkC, spkCS, spkD, spkDS, spkE, spkF
                dw      spkFS, spkG, spkGS, spkA, spkAS, spkB

spkrVoice       dw      0               ; the block currently driving PIT channel 2

tandyBlocks     VOICE   <>
                VOICE   <>
                VOICE   <>
tandyVoice3     VOICE   <>              ; Fourth Tandy voice.

; Four unused Tandy voice blocks.
tandySpare      VOICE   <>
                VOICE   <>
                VOICE   <>
                VOICE   <>

tandyFreq       dw      snA2, snAS2, snB2, snC3, snCS3, snD3
                dw      snDS3, snE3, snF3, snFS3, snG3, snGS3

; ---------------------------------------------------------------------------
; SONG TABLES.  One row per tune id, four stream pointers per row -- voice 0 to
; voice 3. Both voice programmers index by id * 8; a zero pointer preserves that voice.
; ---------------------------------------------------------------------------
; Speaker rows use voice 0; tune 20 also configures other blocks from its setup stream.
songTableA      dw      silentA,     silentA,     silentA,     silentA      ; tune  0
                dw      tuneA01_v0,  silentA,     silentA,     silentA      ; tune  1
                dw      tuneA02_v0,  silentA,     silentA,     silentA      ; tune  2
                dw      tuneA03_v0,  silentA,     silentA,     silentA      ; tune  3
                dw      tuneA04_v0,  silentA,     silentA,     silentA      ; tune  4
                dw      tuneA05_v0,  silentA,     silentA,     silentA      ; tune  5
                dw      tuneA06_v0,  silentA,     silentA,     silentA      ; tune  6
                dw      tuneA07_v0,  silentA,     silentA,     silentA      ; tune  7
                dw      tuneA08_v0,  silentA,     silentA,     silentA      ; tune  8
                dw      tuneA09_v0,  silentA,     silentA,     silentA      ; tune  9
                dw      tuneA10_v0,  silentA,     silentA,     silentA      ; tune 10
                dw      tuneA11_v0,  silentA,     silentA,     silentA      ; tune 11
                dw      tuneA12_v0,  silentA,     silentA,     silentA      ; tune 12
                dw      tuneA13_v0,  silentA,     silentA,     silentA      ; tune 13
                dw      tuneA14_v0,  silentA,     silentA,     silentA      ; tune 14
                dw      tuneA15_v0,  silentA,     silentA,     silentA      ; tune 15
                dw      tuneA16_v0,  silentA,     silentA,     silentA      ; tune 16
                dw      tuneA17_v0,  silentA,     silentA,     silentA      ; tune 17
                dw      tuneA18_v0,  silentA,     silentA,     silentA      ; tune 18
                dw      tuneA19_v0,  silentA,     silentA,     silentA      ; tune 19
                dw      tuneA20_v0,  0,           0,           0            ; tune 20

; Tandy rows include tone and noise streams.
songTableB      dw      silentB,     silentB,     silentB,     silentB      ; tune  0
                dw      tuneB01_v0,  tuneB01_v1,  tuneB01_v2,  silentB      ; tune  1
                dw      silentB,     silentB,     silentB,     tuneB02_v3   ; tune  2
                dw      tuneB03_v0,  tuneB03_v1,  tuneB03_v2,  silentB      ; tune  3
                dw      tuneB04_v0,  silentB,     tuneB04_v2,  tuneB04_v3   ; tune  4
                dw      tuneB05_v0,  silentB,     silentB,     silentB      ; tune  5
                dw      silentB,     silentB,     tuneB06_v2,  tuneB06_v3   ; tune  6
                dw      tuneB07_v0,  tuneB07_v1,  silentB,     silentB      ; tune  7
                dw      silentB,     silentB,     silentB,     tuneB08_v3   ; tune  8
                dw      silentB,     silentB,     silentB,     tuneB09_v3   ; tune  9
                dw      silentB,     silentB,     tuneB10_v2,  tuneB10_v3   ; tune 10
                dw      tuneB11_v0,  tuneB11_v1,  tuneB11_v2,  silentB      ; tune 11
                dw      silentB,     silentB,     tuneB12_v2,  tuneB12_v3   ; tune 12
                dw      tuneB13_v0,  silentB,     tuneB13_v2,  tuneB13_v3   ; tune 13
                dw      silentB,     silentB,     tuneB14_v2,  tuneB14_v3   ; tune 14
                dw      silentB,     silentB,     tuneB15_v2,  tuneB15_v3   ; tune 15
                dw      silentB,     silentB,     tuneB16_v2,  tuneB16_v3   ; tune 16
                dw      silentB,     silentB,     tuneB17_v2,  silentB      ; tune 17
                dw      tuneB18_v0,  silentB,     tuneB18_v2,  tuneB18_v3   ; tune 18
                dw      tuneB19_v0,  silentB,     silentB,     silentB      ; tune 19
                dw      tuneB20_v0,  silentB,     silentB,     silentB      ; tune 20

; ---------------------------------------------------------------------------
; LFO WAVEFORMS.  A voice picks one by pointing vfLfoTable at it; voice_step reads
; a byte, scales it by vfLfoDepth and adds the result to the pitch going out.
; ---------------------------------------------------------------------------
; One sine cycle: 256 signed samples, amplitude 7Eh,
lfoSine         db      000h,003h,006h,009h,00Ch,00Fh,012h,015h,018h,01Bh,01Eh,021h,024h,027h,02Ah,02Dh
                db      030h,033h,036h,039h,03Bh,03Eh,041h,043h,046h,049h,04Bh,04Eh,050h,052h,055h,057h
                db      059h,05Bh,05Eh,060h,062h,064h,066h,067h,069h,06Bh,06Ch,06Eh,070h,071h,072h,074h
                db      075h,076h,077h,078h,079h,07Ah,07Bh,07Bh,07Ch,07Dh,07Dh,07Eh,07Eh,07Eh,07Eh,07Eh
                db      07Eh,07Eh,07Eh,07Eh,07Eh,07Eh,07Dh,07Dh,07Ch,07Bh,07Bh,07Ah,079h,078h,077h,076h
                db      075h,074h,072h,071h,070h,06Eh,06Ch,06Bh,069h,067h,066h,064h,062h,060h,05Eh,05Bh
                db      059h,057h,055h,052h,050h,04Eh,04Bh,049h,046h,043h,041h,03Eh,03Bh,039h,036h,033h
                db      030h,02Dh,02Ah,027h,024h,021h,01Eh,01Bh,018h,015h,012h,00Fh,00Ch,009h,006h,003h
                db      000h,0FDh,0FAh,0F7h,0F4h,0F1h,0EEh,0EBh,0E8h,0E5h,0E2h,0DFh,0DCh,0D9h,0D6h,0D3h
                db      0D0h,0CDh,0CAh,0C7h,0C5h,0C2h,0BFh,0BDh,0BAh,0B7h,0B5h,0B2h,0B0h,0AEh,0ABh,0A9h
                db      0A7h,0A5h,0A2h,0A0h,09Eh,09Ch,09Ah,099h,097h,095h,094h,092h,090h,08Fh,08Eh,08Ch
                db      08Bh,08Ah,089h,088h,087h,086h,085h,085h,084h,083h,083h,082h,082h,082h,082h,082h
                db      082h,082h,082h,082h,082h,082h,083h,083h,084h,085h,085h,086h,087h,088h,089h,08Ah
                db      08Bh,08Ch,08Eh,08Fh,090h,092h,094h,095h,097h,099h,09Ah,09Ch,09Eh,0A0h,0A2h,0A5h
                db      0A7h,0A9h,0ABh,0AEh,0B0h,0B2h,0B5h,0B7h,0BAh,0BDh,0BFh,0C2h,0C5h,0C7h,0CAh,0CDh
                db      0D0h,0D3h,0D6h,0D9h,0DCh,0DFh,0E2h,0E5h,0E8h,0EBh,0EEh,0F1h,0F4h,0F7h,0FAh,0FDh

; Zero samples, followed by constant samples; the selected wrap can span both regions.
lfoZero         db      000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h

; Constant samples for a positive pitch offset.
lfoFlat         db      078h,078h,078h,078h,078h,078h,078h,078h,078h,078h,078h,078h,078h,078h,078h,078h

; Pseudo-random waveform for percussion and sound effects.
lfoNoise        db      029h,023h,0BEh,084h,0E1h,06Ch,0D6h,0AEh,052h,090h,049h,0F1h,0F1h,0BBh,0E9h,0EBh
                db      0B3h,0A6h,0DBh,03Ch,087h,00Ch,03Eh,099h,024h,05Eh,00Dh,01Ch,006h,0B7h,047h,0DEh
                db      0B3h,012h,04Dh,0C8h,043h,0BBh,08Bh,0A6h,01Fh,003h,05Ah,07Dh,009h,038h,025h,01Fh
                db      05Dh,0D4h,0CBh,0FCh,096h,0F5h,045h,03Bh,013h,00Dh,089h,00Ah,01Ch,0DBh,0AEh,032h
                db      020h,09Ah,050h,0EEh,040h,078h,036h,0FDh,012h,049h,032h,0F6h,09Eh,07Dh,049h,0DCh
                db      0ADh,04Fh,014h,0F2h,044h,040h,066h,0D0h,06Bh,0C4h,030h,0B7h,032h,03Bh,0A1h,022h
                db      0F6h,022h,091h,09Dh,0E1h,08Bh,01Fh,0DAh,0B0h,0CAh,099h,002h,0B9h,072h,09Dh,049h
                db      02Ch,080h,07Eh,0C5h,099h,0D5h,0E9h,080h,0B2h,0EAh,0C9h,0CCh,053h,0BFh,067h,0D6h
                db      0BFh,014h,0D6h,07Eh,02Dh,0DCh,08Eh,066h,083h,0EFh,057h,049h,061h,0FFh,069h,08Fh
                db      061h,0CDh,0D1h,01Eh,09Dh,09Ch,016h,072h,072h,0E6h,01Dh,0F0h,084h,04Fh,04Ah,077h
                db      002h,0D7h,0E8h,039h,02Ch,053h,0CBh,0C9h,012h,01Eh,033h,074h,09Eh,00Ch,0F4h,0D5h
                db      0D4h,09Fh,0D4h,0A4h,059h,07Eh,035h,0CFh,032h,022h,0F4h,0CCh,0CFh,0D3h,090h,02Dh
                db      048h,0D3h,08Fh,075h,0E6h,0D9h,01Dh,02Ah,0E5h,0C0h,0F7h,02Bh,078h,081h,087h,044h
                db      00Eh,05Fh,050h,000h,0D4h,061h,08Dh,0BEh,07Bh,005h,015h,007h,03Bh,033h,082h,01Fh
                db      018h,070h,092h,0DAh,064h,054h,0CEh,0B1h,085h,03Eh,069h,015h,0F8h,046h,06Ah,004h
                db      096h,073h,00Eh,0D9h,016h,02Fh,067h,068h,0D4h,0F7h,04Ah,04Ah,0D0h,057h,068h,076h
                db      0FAh,016h,0BBh,011h,0ADh,0AEh,024h,088h,079h,0FEh,052h,0DBh,025h,043h,0E5h,03Ch
                db      0F4h,045h,0D3h,0D8h,028h,0CEh,00Bh,0F5h,0C5h,060h,059h,03Dh,097h,027h,08Ah,059h
                db      076h,02Dh,0D0h,0C2h,0C9h,0CDh,068h,0D4h,049h,06Ah,079h,025h,008h,061h,040h,014h
                db      0B1h,03Bh,06Ah,0A5h,011h,028h,0C1h,08Ch,0D6h,0A9h,00Bh,087h,097h,08Ch,02Fh,0F1h
                db      015h,01Dh,09Ah,095h,0C1h,09Bh,0E1h,0C0h,07Eh,0E9h,0A8h,09Ah,0A7h,086h,0C2h,0B5h
                db      054h,0BFh,09Ah,0E7h,0D9h,023h,0D1h,055h,090h,038h,028h,0D1h,0D9h,06Ch,0A1h,066h
                db      05Eh,04Eh,0E1h,030h,09Ch,0FEh,0D9h,071h,09Fh,0E2h,0A5h,0E2h,00Ch,09Bh,0B4h,047h
                db      065h,038h,02Ah,046h,089h,0A9h,082h,079h,07Ah,076h,078h,0C2h,063h,0B1h,026h,0DFh
                db      0DAh,029h,06Dh,03Eh,062h,0E0h,096h,012h,034h,0BFh,039h,0A6h,03Fh,089h,05Eh,0F1h
                db      06Dh,00Eh,0E3h,06Ch,028h,0A1h,01Eh,020h,01Dh,0CBh,0C2h,003h,03Fh,041h,007h,084h
                db      00Fh,014h,005h,065h,01Bh,028h,061h,0C9h,0C5h,0E7h,02Ch,08Eh,046h,036h,008h,0DCh
                db      0F3h,0A8h,08Dh,0FEh,0BEh,0F2h,0EBh,071h,0FFh,0A0h,0D0h,03Bh,075h,006h,08Ch,07Eh
                db      087h,078h,073h,04Dh,0D0h,0BEh,082h,0BEh,0DBh,0C2h,046h,041h,02Bh,08Ch,0FAh,030h
                db      07Fh,070h,0F0h,0A7h,054h,086h,032h,095h,0AAh,05Bh,068h,013h,00Bh,0E6h,0FCh,0F5h
                db      0CAh,0BEh,07Dh,09Fh,089h,08Ah,041h,01Bh,0FDh,0B8h,04Fh,068h,0F6h,072h,07Bh,014h
                db      099h,0CDh,0D3h,00Dh,0F0h,044h,03Ah,0B4h,0A6h,066h,053h,033h,00Bh,0CBh,0A1h,010h

; ---------------------------------------------------------------------------
; Streams and envelopes referenced by the song tables and stream operands.
; ---------------------------------------------------------------------------
; Pitches are scale degrees above the active note table's base -- C for the speaker
; table, A for the Tandy one -- not concert pitches.  seq_note adds the voice's
; vfTranspose, then reduces to an octave and a semitone.
NT_C    equ 0
NT_CS   equ 1
NT_D    equ 2
NT_DS   equ 3
NT_E    equ 4
NT_F    equ 5
NT_FS   equ 6
NT_G    equ 7
NT_GS   equ 8
NT_A    equ 9
NT_AS   equ 10
NT_B    equ 11
OCT     equ 12                      ; one octave
REST    equ 7Fh                     ; the pitch that sounds nothing

; One macro per sequencer record, each emitting the record the driver decodes.
SRESET  MACRO                       ;; 0FAh -- clear the voice this stream is on
        db 0FAh
        ENDM
SRET    MACRO                       ;; 0FBh -- back to the stream SCALL came from
        db 0FBh
        ENDM
SCALL   MACRO target                ;; 0FCh -- call a stream; seqRet holds one level
        db 0FCh
        dw target
        ENDM
SCLEAR  MACRO vnum                  ;; 0FDh -- move this stream onto voice vnum of
        db 0FDh                     ;;         the active device and clear it
        dw (vnum) * SIZE VOICE
        ENDM
SLOOP   MACRO field, target         ;; 0FEh -- jump if field is zero or decrements to nonzero
        db 0FEh, field
        dw target
        ENDM
SSET    MACRO field, value          ;; 0FFh -- store a word into a voice field
        db 0FFh, field
        dw value
        ENDM
SWAIT   MACRO ticks                 ;; SSET of vfDuration, which also yields.  Ticks 0
        db 0FFh, 000h               ;;   ends the stream: seq_end sees the zero and
        dw ticks                    ;;   drops the voice
        ENDM
ENV_SETLEVEL equ 0FFFFh             ; in a segment's ticks slot: value is a level to
                                    ;   load, and the next segment runs on the same tick
SENV    MACRO value, ticks          ;; one envelope segment
        dw value, ticks
        ENDM
SNOTE   MACRO vnum, len, pitch, last, dur   ; A note record with explicit duration; len is unused.
        db ((vnum) SHL 5) OR (len), ((last) SHL 7) OR (pitch), dur
        ENDM

tuneA10_v0:
        SSET    vfLevel,         3
        SSET    vfPeriod,        7530h
        SSET    vfLfoTable,      lfoNoise
        SSET    vfLfoWrap,       2000h
        SSET    vfLfoDepth,      2710h
        SSET    vfLfoRate,       10h
        SWAIT   28
        SSET    vfLevel,         0
        SWAIT   12
        SSET    vfLevel,         3
        SSET    vfPeriod,        1004h
        SSET    vfLfoDepth,      898h
        SSET    vfPeriodAdd,     10h
        SWAIT   300
        SSET    vfLevel,         0
        SWAIT   0
tuneA12_v0:
        SSET    vfLevel,         3
        SSET    vfPeriod,        2710h
        SSET    vfLfoTable,      lfoNoise
        SSET    vfLfoWrap,       2000h
        SSET    vfLfoDepth,      2328h
        SSET    vfLfoRate,       10h
        SWAIT   25
        SSET    vfLevel,         0
        SWAIT   2
        SSET    vfLevel,         3
        SSET    vfPeriod,        1388h
        SSET    vfLfoDepth,      0FA0h
        SSET    vfPeriodAdd,     12Ch
        SWAIT   80
        SSET    vfLevel,         0
        SWAIT   0
tuneA13_v0:
        SSET    vfLevel,         3
        SSET    vfPeriod,        0BB8h
        SSET    vfLfoTable,      lfoNoise
        SSET    vfLfoWrap,       2000h
        SSET    vfLfoDepth,      44Ch
        SSET    vfLfoRate,       10h
        SWAIT   2
        SSET    vfLevel,         0
        SWAIT   1
        SSET    vfLevel,         3
        SSET    vfPeriod,        834h
        SSET    vfLfoDepth,      1F4h
        SSET    vfPeriodAdd,     0FF9Ch
        SWAIT   30
        SSET    vfLevel,         0
        SWAIT   0
tuneA18_v0:
        SSET    vfLevel,         3
        SSET    vfPeriod,        1F40h
        SSET    vfLfoTable,      lfoNoise
        SSET    vfLfoWrap,       2000h
        SSET    vfLfoDepth,      44Ch
        SSET    vfLfoRate,       10h
        SWAIT   2
        SSET    vfLevel,         0
        SWAIT   1
        SSET    vfLevel,         3
        SSET    vfPeriod,        17D4h
        SSET    vfLfoDepth,      1F4h
        SSET    vfPeriodAdd,     0FF9Ch
        SWAIT   80
        SSET    vfLevel,         0
        SWAIT   0
tuneA16_v0:
        SSET    vfLevel,         3
        SSET    vfLfoTable,      lfoNoise
        SSET    vfLfoWrap,       2000h
        SSET    vfLfoDepth,      3E8h
        SSET    vfLfoRate,       10h
        SSET    vfPeriodAdd,     0FFCEh
        SSET    vfLoopCounterA,  4
tuneA16_v0_loop:
        SSET    vfPeriod,        2710h
        SWAIT   4
        SSET    vfPeriod,        4E20h
        SSET    vfLevel,         0
        SWAIT   4
        SSET    vfLevel,         3
        SWAIT   4
        SLOOP   vfLoopCounterA, tuneA16_v0_loop
        SSET    vfLevel,         0
        SWAIT   0
tuneA17_v0:
        SSET    vfLevel,         3
        SSET    vfLfoTable,      lfoNoise
        SSET    vfLfoWrap,       2000h
        SSET    vfLfoDepth,      3E8h
        SSET    vfLfoRate,       10h
        SSET    vfPeriodAdd,     0FFCEh
        SSET    vfLoopCounterA,  20
tuneA17_v0_loop:
        SSET    vfPeriod,        1388h
        SWAIT   1
        SSET    vfLevel,         0
        SWAIT   1
        SSET    vfLevel,         3
        SSET    vfPeriod,        7530h
        SWAIT   1
        SLOOP   vfLoopCounterA, tuneA17_v0_loop
        SSET    vfLevel,         0
        SWAIT   0
tuneA14_v0:
        SSET    vfLevel,         3
        SSET    vfPeriod,        2710h
        SSET    vfLfoTable,      lfoNoise
        SSET    vfLfoWrap,       2000h
        SSET    vfLfoDepth,      1F4h
        SSET    vfLfoRate,       10h
        SSET    vfPeriodAdd,     0FFCEh
        SWAIT   28
        SSET    vfLevel,         0
        SWAIT   0
tuneA15_v0:
        SSET    vfLevel,         3
        SSET    vfPeriod,        4E20h
        SSET    vfLfoTable,      lfoNoise
        SSET    vfLfoWrap,       2000h
        SSET    vfLfoDepth,      2710h
        SSET    vfLfoRate,       10h
        SWAIT   5
        SSET    vfLevel,         0
        SWAIT   1
        SSET    vfLevel,         3
        SSET    vfPeriod,        834h
        SSET    vfLfoDepth,      898h
        SSET    vfPeriodAdd,     64h
        SWAIT   100
        SSET    vfLevel,         0
        SWAIT   0
tuneA08_v0:
        SSET    vfLevel,         3
        SSET    vfPeriod,        0FA0h
        SWAIT   5
        SSET    vfPeriod,        3E8h
        SWAIT   4
        SSET    vfLevel,         0
        SWAIT   0
tuneA09_v0:
        SSET    vfLevel,         3
        SSET    vfPeriod,        36B0h
        SSET    vfPeriodAdd,     0C8h
        SSET    vfLfoTable,      lfoNoise
        SSET    vfLfoWrap,       2000h
        SSET    vfLfoDepth,      1770h
        SSET    vfLfoRate,       7Bh
        SWAIT   8
        SSET    vfLevel,         0
        SWAIT   0
tuneA07_v0:
        SSET    vfLevel,         3
        SSET    vfPeriod,        3FB4h
        SSET    vfLoopCounterA,  30
tuneA07_v0_loop:
        SSET    vfPeriodAdd,     0FE3Ch
        SWAIT   12
        SSET    vfPeriodAdd,     277h
        SWAIT   8
        SLOOP   vfLoopCounterA, tuneA07_v0_loop
        SSET    vfLevel,         0
        SWAIT   0
tuneA02_v0:
        SSET    vfLevel,         3
        SSET    vfLfoTable,      lfoNoise
        SSET    vfLfoWrap,       2000h
        SSET    vfLfoDepth,      640h
        SSET    vfLfoRate,       19Bh
        SSET    vfPeriod,        10CCh
        SSET    vfPeriodAdd,     0Ah
        SWAIT   30
        SSET    vfLfoDepth,      384h
        SSET    vfPeriod,        514h
        SSET    vfPeriodAdd,     50h
        SWAIT   5
        SSET    vfLevel,         0
        SWAIT   0
tuneA05_v0:
        SSET    vfLevel,         3
        SSET    vfLoopCounterA,  5
        SSET    vfPeriod,        1838h
tuneA05_v0_loopOuter:
        SSET    vfPeriodAdd,     0
        SWAIT   6
        SSET    vfLoopCounterB,  12
tuneA05_v0_loopInner:
        SSET    vfPeriodAdd,     0FC5Eh
        SWAIT   1
        SSET    vfPeriodAdd,     384h
        SWAIT   1
        SLOOP   vfLoopCounterB, tuneA05_v0_loopInner
        SLOOP   vfLoopCounterA, tuneA05_v0_loopOuter
        SSET    vfLevel,         0
        SWAIT   0
tuneA03_v0:
        SSET    vfLevel,         3
        SSET    vfPeriod,        197Bh
        SSET    vfLoopCounterA,  10
tuneA03_v0_loop:
        SSET    vfPeriodAdd,     0FFD3h
        SWAIT   20
        SSET    vfPeriodAdd,     1F4h
        SWAIT   1
        SLOOP   vfLoopCounterA, tuneA03_v0_loop
        SSET    vfLevel,         0
        SWAIT   0
tuneA04_v0:
        SSET    vfLevel,         3
        SSET    vfLfoTable,      lfoNoise
        SSET    vfLfoWrap,       2000h
        SSET    vfLfoDepth,      2710h
        SSET    vfLfoRate,       10h
        SSET    vfPeriod,        2EE0h
        SSET    vfLoopCounterA,  44
tuneA04_v0_loop:
        SSET    vfPeriodAdd,     0F1F0h
        SWAIT   2
        SSET    vfPeriodAdd,     0E88h
        SWAIT   2
        SLOOP   vfLoopCounterA, tuneA04_v0_loop
        SSET    vfLevel,         0
        SWAIT   0
tuneA06_v0:
        SSET    vfLevel,         3
        SSET    vfLfoTable,      lfoNoise
        SSET    vfLfoWrap,       2000h
        SSET    vfLfoDepth,      0A28h
        SSET    vfLfoRate,       10h
        SSET    vfPeriod,        1770h
        SSET    vfPeriodAdd,     0FF60h
        SWAIT   30
        SSET    vfPeriodAdd,     46h
        SWAIT   35
        SSET    vfLevel,         0
        SWAIT   0
silentA:
        SSET    vfLevel,         0
        SWAIT   0
tuneA01_v0:
        SSET    vfLevel,         3
        SSET    vfPeriod,        1388h
        SSET    vfLfoTable,      lfoSine
        SSET    vfLfoWrap,       1000h
        SSET    vfLfoDepth,      1F4h
        SSET    vfLfoRate,       4Eh
        SSET    vfLoopCounterA,  40
tuneA01_v0_loop:
        SSET    vfPeriodAdd,     0
        SWAIT   2
        SSET    vfPeriodAdd,     0FDADh
        SWAIT   1
        SSET    vfPeriodAdd,     0
        SWAIT   2
        SSET    vfPeriodAdd,     1F4h
        SWAIT   1
        SLOOP   vfLoopCounterA, tuneA01_v0_loop
        SSET    vfLevel,         0
        SWAIT   0
tuneA11_v0:
        SSET    vfLevel,         3
        SSET    vfLfoTable,      lfoSine
        SSET    vfLfoWrap,       1000h
        SSET    vfLfoDepth,      3E8h
        SSET    vfLfoRate,       100h
        SSET    vfPeriod,        0CE4h
        SSET    vfPeriodAdd,     0FFECh
        SWAIT   30
        SSET    vfLevel,         0
        SWAIT   0
tuneA20_v0:
        SCALL   tuneA20_setup
        SWAIT   0
tuneA20_setup:
        SCLEAR  1
        SSET    vfTranspose,     0FFE8h
        SSET    vfEnvBase,       tuneA20_env_v1
        SSET    vfLfoTable,      lfoSine
        SSET    vfLfoWrap,       1000h
        SSET    vfLfoDepth,      28h
        SSET    vfLfoRate,       12Ch
        SCLEAR  2
        SSET    vfTranspose,     0FFE8h
        SSET    vfReleaseLead,   5
        SSET    vfEnvBase,       tuneA20_env_v2
        SSET    vfLfoTable,      lfoSine
        SSET    vfLfoWrap,       1000h
        SSET    vfLfoDepth,      14h
        SSET    vfLfoRate,       78h
        SCLEAR  0
        SSET    vfTranspose,     0FFE8h
        SSET    vfEnvBase,       tuneA20_env_v0
        SSET    vfLfoTable,      lfoSine
        SSET    vfLfoWrap,       1000h
        SSET    vfLfoDepth,      78h
        SSET    vfLfoRate,       0E4h
        SCLEAR  3
        SSET    vfTranspose,     0FFE8h
        SSET    vfEnvBase,       tuneA20_env_v3
        SSET    vfLfoTable,      lfoSine
        SSET    vfLfoWrap,       1000h
        SSET    vfLfoDepth,      78h
        SSET    vfLfoRate,       0E4h
        SSET    vfTempo,         1
        SRET
tuneA20_env_v2:
        SENV    3,               ENV_SETLEVEL
        SENV    0,               0
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0
tuneA20_env_v1:
        SENV    3,               ENV_SETLEVEL
        SENV    0,               16
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0
        SENV    0,               30
        SENV    0,               0
tuneA20_env_v0:
        SENV    3,               ENV_SETLEVEL
        SENV    0,               8
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0
        SENV    0,               30
        SENV    0,               0
tuneA20_env_v3:
        SENV    3,               ENV_SETLEVEL
        SENV    0,               20
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0
        SENV    0,               30
        SENV    0,               0
tuneA19_v0:
        SSET    vfLevel,         3
        SSET    vfPeriod,        0FA0h
        SSET    vfPeriodAdd,     14h
        SWAIT   16
        SSET    vfLevel,         0
        SWAIT   0
tuneB10_v2:
        SSET    vfPeriod,        0BB8h
        SWAIT   28
        SSET    vfPeriod,        3E80h
        SSET    vfPeriodAdd,     0FFE7h
        SWAIT   400
        SWAIT   0
tuneB10_v3:
        SSET    vfPeriod,        1C0h
        SSET    vfLevel,         0EA60h
        SWAIT   28
        SSET    vfLevel,         0C350h
        SSET    vfLevelAdd,      0FF9Ch
        SWAIT   400
        SSET    vfLevel,         0
        SWAIT   0
tuneB12_v2:
        SSET    vfPeriod,        0BB8h
        SWAIT   18
        SSET    vfPeriod,        3E80h
        SSET    vfPeriodAdd,     0FFE7h
        SWAIT   100
        SWAIT   0
tuneB12_v3:
        SSET    vfPeriod,        1C0h
        SSET    vfLevel,         0EA60h
        SWAIT   18
        SSET    vfLevel,         0C350h
        SSET    vfLevelAdd,      0FF9Ch
        SWAIT   100
        SSET    vfLevel,         0
        SWAIT   0
tuneB13_v2:
        SSET    vfPeriod,        2328h
        SSET    vfPeriodAdd,     0FFE7h
        SWAIT   25
        SWAIT   0
tuneB13_v3:
        SSET    vfPeriod,        1C0h
        SSET    vfLevel,         0D6D8h
        SSET    vfLevelAdd,      0FF9Ch
        SWAIT   25
        SSET    vfLevel,         0
        SWAIT   0
tuneB13_v0:
        SSET    vfPeriod,        0FA0h
        SSET    vfLevel,         9C40h
        SSET    vfLevelAdd,      0FF9Ch
        SSET    vfPeriodAdd,     0FF9Ch
        SWAIT   25
        SSET    vfLevel,         0
        SWAIT   0
tuneB18_v2:
        SSET    vfPeriod,        2710h
        SSET    vfPeriodAdd,     0FFE7h
        SWAIT   55
        SWAIT   0
tuneB18_v3:
        SSET    vfPeriod,        1C0h
        SSET    vfLevel,         0EA60h
        SSET    vfLevelAdd,      0FF9Ch
        SWAIT   55
        SSET    vfLevel,         0
        SWAIT   0
tuneB18_v0:
        SSET    vfPeriod,        1B58h
        SRET
; Stream-formatted tail after the return; no song-table entry points here.
tuneB18_v0_tail:
        SNOTE   0, 10, NT_E+3*OCT, 0, 160
        SSET    vfLevelAdd,      0FF9Ch
        SSET    vfPeriodAdd,     0FF9Ch
        SWAIT   55
        SSET    vfLevel,         0
        SWAIT   0
tuneB16_v2:
        SSET    vfPeriod,        1F40h
        SWAIT   40
        SWAIT   0
tuneB16_v3:
        SSET    vfPeriod,        1C0h
        SSET    vfLoopCounterA,  4
tuneB16_v3_loop:
        SSET    vfLevel,         0D6D8h
        SWAIT   5
        SSET    vfLevel,         1
        SWAIT   5
        SLOOP   vfLoopCounterA, tuneB16_v3_loop
        SSET    vfLevel,         0
        SWAIT   0
tuneB17_v2:
        SSET    vfLoopCounterA,  20
tuneB17_v2_loop:
        SSET    vfPeriod,        1770h
        SSET    vfLevel,         0C350h
        SWAIT   1
        SSET    vfPeriod,        1388h
        SSET    vfLevel,         1
        SWAIT   1
        SSET    vfPeriod,        7530h
        SSET    vfLevel,         0C350h
        SWAIT   1
        SLOOP   vfLoopCounterA, tuneB17_v2_loop
        SSET    vfLevel,         0
        SWAIT   0
tuneB14_v2:
        SSET    vfPeriod,        0FA0h
        SWAIT   28
        SWAIT   0
tuneB14_v3:
        SSET    vfPeriod,        1C0h
        SSET    vfLevel,         0C350h
        SWAIT   28
        SSET    vfLevel,         0
        SWAIT   0
tuneB15_v2:
        SSET    vfPeriod,        2710h
        SWAIT   5
        SSET    vfPeriod,        0FA0h
        SSET    vfPeriodAdd,     64h
        SWAIT   100
        SWAIT   0
tuneB15_v3:
        SSET    vfPeriod,        1C0h
        SSET    vfLevel,         0EA60h
        SWAIT   5
        SSET    vfLevel,         0C350h
        SSET    vfLevelAdd,      0FF9Ch
        SWAIT   100
        SSET    vfLevel,         0
        SWAIT   0
tuneB08_v3:
        SSET    vfPeriod,        100h
        SSET    vfLevel,         7530h
        SSET    vfLevelAdd,      3E8h
        SWAIT   20
        SSET    vfLevelAdd,      0FC18h
        SWAIT   40
        SSET    vfLevel,         0
        SWAIT   0
tuneB09_v3:
        SSET    vfPeriod,        180h
        SSET    vfLevel,         0EA60h
        SSET    vfLevelAdd,      0F254h
        SWAIT   16
        SSET    vfLevel,         0
        SWAIT   0
tuneB07_v1:
        SWAIT   4
tuneB07_v0:
        SSET    vfLevel,         0EA60h
        SSET    vfLevelAdd,      0FF9Ch
        SSET    vfPeriod,        0FDE8h
        SSET    vfLoopCounterA,  30
tuneB07_v0_loop:
        SSET    vfPeriodAdd,     0FD8Ah
        SWAIT   12
        SSET    vfPeriodAdd,     276h
        SWAIT   8
        SLOOP   vfLoopCounterA, tuneB07_v0_loop
        SSET    vfLevel,         0
        SWAIT   0
tuneB06_v2:
        SSET    vfPeriod,        7D0h
        SSET    vfPeriodAdd,     5Ah
        SWAIT   20
        SWAIT   0
tuneB06_v3:
        SSET    vfPeriod,        1C0h
        SSET    vfLevel,         0EA60h
        SSET    vfLevelAdd,      0F830h
        SWAIT   20
        SSET    vfLevel,         0
        SWAIT   0
tuneB05_v0:
        SSET    vfPeriod,        9C2h
        SSET    vfLevel,         7530h
        SSET    vfLoopCounterA,  12
tuneB05_v0_loop:
        SSET    vfPeriodAdd,     0FFF7h
        SWAIT   12
        SSET    vfPeriodAdd,     9
        SWAIT   8
        SLOOP   vfLoopCounterA, tuneB05_v0_loop
        SSET    vfLevel,         0
        SWAIT   0
tuneB03_v2:
        SWAIT   20
tuneB03_v1:
        SWAIT   20
tuneB03_v0:
        SSET    vfPeriod,        98E3h
        SSET    vfLevel,         0EA60h
        SSET    vfLevelAdd,      0FF38h
        SSET    vfPeriodAdd,     0FF4Eh
        SWAIT   200
        SSET    vfLevel,         0
        SWAIT   0
tuneB04_v0:
        SSET    vfLevel,         2710h
        SSET    vfLevelAdd,      1F4h
        SSET    vfPeriod,        0FA00h
        SSET    vfPeriodAdd,     0FF10h
        SWAIT   80
        SSET    vfLevelAdd,      0
        SSET    vfLoopCounterA,  44
tuneB04_v0_loop:
        SSET    vfPeriodAdd,     0FB50h
        SWAIT   2
        SSET    vfPeriodAdd,     4D8h
        SWAIT   2
        SLOOP   vfLoopCounterA, tuneB04_v0_loop
        SSET    vfLevelAdd,      0FE61h
        SSET    vfPeriodAdd,     3Ch
        SWAIT   120
        SSET    vfLevel,         0
        SWAIT   0
tuneB04_v2:
        SSET    vfPeriod,        1130h
        SSET    vfPeriodAdd,     0Bh
        SWAIT   188
        SSET    vfPeriodAdd,     0FFF5h
        SWAIT   188
        SWAIT   0
tuneB04_v3:
        SSET    vfPeriod,        1C0h
        SSET    vfLevel,         61A8h
        SSET    vfLevelAdd,      9Fh
        SWAIT   188
        SSET    vfLevelAdd,      0FF61h
        SWAIT   188
        SSET    vfLevel,         0
        SWAIT   0
tuneB02_v3:
        SSET    vfLevelAdd,      960h
        SSET    vfPeriod,        100h
        SWAIT   25
        SSET    vfLevelAdd,      0F6A0h
        SWAIT   25
        SSET    vfLevel,         0
        SWAIT   0
silentB:
        SSET    vfLevel,         0
        SWAIT   0
tuneB01_v0:
        SSET    vfLevel,         0EA60h
        SSET    vfLevelAdd,      0FF15h
        SSET    vfPeriod,        1FE0h
        SSET    vfLoopCounterA,  6
tuneB01_v0_loop:
        SSET    vfPeriodAdd,     1Eh
        SWAIT   16
        SSET    vfPeriodAdd,     0FFE2h
        SWAIT   16
        SLOOP   vfLoopCounterA, tuneB01_v0_loop
        SSET    vfLevel,         0
        SWAIT   0
tuneB01_v1:
        SSET    vfLevel,         0C350h
        SSET    vfLevelAdd,      0FF38h
        SSET    vfPeriod,        4010h
        SSET    vfLoopCounterA,  10
tuneB01_v1_loop:
        SSET    vfPeriodAdd,     42h
        SWAIT   8
        SSET    vfPeriodAdd,     0FFBEh
        SWAIT   8
        SLOOP   vfLoopCounterA, tuneB01_v1_loop
        SSET    vfLevel,         0
        SWAIT   0
tuneB01_v2:
        SSET    vfLevel,         0FDE8h
        SSET    vfLevelAdd,      0FED4h
        SSET    vfPeriod,        36B0h
        SSET    vfLoopCounterA,  8
tuneB01_v2_loop:
        SSET    vfPeriodAdd,     52h
        SWAIT   12
        SSET    vfPeriodAdd,     0FFB2h
        SWAIT   12
        SLOOP   vfLoopCounterA, tuneB01_v2_loop
        SSET    vfLevel,         0
        SWAIT   0
tuneB11_v0:
        SSET    vfLevel,         0EA60h
        SSET    vfLevelAdd,      0FB50h
        SSET    vfPeriod,        34D0h
        SWAIT   30
        SSET    vfLevel,         0
        SWAIT   0
tuneB11_v1:
        SSET    vfLevel,         0EA60h
        SSET    vfLevelAdd,      0FB50h
        SSET    vfPeriod,        8020h
        SWAIT   30
        SSET    vfLevel,         0
        SWAIT   0
tuneB11_v2:
        SSET    vfLevel,         0EA60h
        SSET    vfLevelAdd,      0FB50h
        SSET    vfPeriod,        1770h
        SWAIT   10
        SSET    vfLevel,         0
        SWAIT   0
tuneB20_v0:
        SCALL   tuneB20_setup
        SWAIT   0
tuneB20_setup:
        SCLEAR  1
        SSET    vfReleaseLead,   0Ch
        SSET    vfTranspose,     0FFD3h
        SSET    vfEnvBase,       tuneB20_env_v1
        SSET    vfLfoTable,      lfoSine
        SSET    vfLfoWrap,       1000h
        SSET    vfLfoDepth,      28h
        SSET    vfLfoRate,       12Ch
        SCLEAR  2
        SSET    vfReleaseLead,   7
        SSET    vfTranspose,     0FFD3h
        SSET    vfEnvBase,       tuneB20_env_v2
        SSET    vfLfoTable,      lfoSine
        SSET    vfLfoWrap,       1000h
        SSET    vfLfoDepth,      16h
        SSET    vfLfoRate,       78h
        SCLEAR  0
        SSET    vfReleaseLead,   7
        SSET    vfTranspose,     0FFD3h
        SSET    vfEnvBase,       tuneB20_env_v0
        SSET    vfLfoTable,      lfoZero
        SSET    vfLfoWrap,       200h
        SSET    vfLfoDepth,      0C8h
        SSET    vfLfoRate,       10h
        SSET    vfTempo,         6
        SRET
tuneB20_env_v2:
        SENV    0C350h,          ENV_SETLEVEL
        SENV    9C4h,            4
        SENV    0F830h,          6
        SENV    0,               0
        SENV    0BB80h,          ENV_SETLEVEL
        SENV    0E0C0h,          6
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0
tuneB20_env_v1:
        SENV    9C40h,           ENV_SETLEVEL
        SENV    9C4h,            8
        SENV    0F448h,          5
        SENV    0,               0
        SENV    0AFC8h,          ENV_SETLEVEL
        SENV    0F060h,          11
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0
tuneB20_env_v0:
        SENV    0DEA8h,          ENV_SETLEVEL
        SENV    0FA24h,          6
        SENV    0,               0
        SENV    0,               0
        SENV    0BB80h,          ENV_SETLEVEL
        SENV    0E0C0h,          6
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0
tuneB19_v0:
        SSET    vfPeriod,        1F40h
        SSET    vfLevel,         7530h
        SSET    vfPeriodAdd,     14h
        SSET    vfLevelAdd,      0FF9Ch
        SWAIT   16
        SSET    vfLevel,         0
        SWAIT   0

; Saved BIOS timer vector, restored by UninstallSoundTimer.
oldInt8Off      dw      0
oldInt8Seg      dw      0

; ---------------------------------------------------------------------------
; Playback routines.
; ---------------------------------------------------------------------------
; Channel 0 retains the BIOS periodic low/high-byte setup. The control write
; below selects channel 2; only the period writes address channel 0.
InstallSoundTimer:
        push    ds
        push    es
        mov     ax, CODE
        mov     ds, ax
        mov     ax, 3508h               ; DOS get-vector, INT 8
        int     21h
        mov     cs:[oldInt8Off], bx     ; keep the handler we are displacing
        mov     cs:[oldInt8Seg], es
        push    ds
        mov     dx, CODE
        mov     ds, dx
        mov     dx, offset P_isr
        mov     ax, 2508h               ; DOS set-vector, INT 8
        int     21h
        pop     ds
        mov     al, 0B6h                ; selects PIT ch2, lo/hi, mode 3; divisor below goes to ch0
        out     43h, al
        mov     ax, 13B1h               ; ch0 divisor 5041 under the inherited BIOS setup
        out     40h, al
        mov     al, ah
        out     40h, al
        pop     es
        pop     ds
        retf

UninstallSoundTimer:
        push    ds
        mov     ax, CODE
        mov     ds, ax
        push    ds
        mov     dx, cs:[oldInt8Off]
        mov     ax, cs:[oldInt8Seg]
        mov     ds, ax
        mov     ax, 2508h               ; put the displaced handler back
        int     21h
        pop     ds
        mov     ax, 0FFFFh              ; ch0 divisor 65535 under the inherited BIOS setup
        out     40h, al
        mov     al, ah
        out     40h, al
        in      al, 61h                 ; drop the speaker gate and the timer gate
        and     al, 0FCh
        out     61h, al
        mov     al, 09Fh                ; full attenuation on the SN76489's
        out     0C0h, al                ;   three tone voices and its noise voice
        mov     al, 0BFh
        out     0C0h, al
        mov     al, 0DFh
        out     0C0h, al
        mov     al, 0FFh
        out     0C0h, al
        pop     ds
        retf

; The timer ISR.  It runs with interrupts on, so seqBusy and not the interrupt flag
; is what keeps it out of the voice writers.
P_isr:
        sti
        push    ax
        push    bx
        push    dx
        push    ds
        push    si
        mov     ax, CODE
        mov     ds, ax
        cmp     ds:[exitCount], 0
        jz      isr_tick
        dec     ds:[exitCount]
        jnz     isr_tick
        mov     ah, 0Fh                 ; read the video mode, then set it again,
        int     10h                     ;   which clears the screen
        mov     ah, 0
        int     10h
        mov     bl, 7
        mov     ah, 7Fh                 ; strip bit 7 off exitMsg in place
        mov     cx, 33
        mov     bx, CODE
        mov     es, bx
        mov     bx, offset exitMsg
isr_msgclr:
        mov     al, es:[bx]
        and     al, ah
        mov     es:[bx], al
        inc     bx
        loop    isr_msgclr
        mov     bl, 7
        mov     ah, 13h                 ; write string, attribute in BL, move cursor
        mov     al, 1
        mov     bh, 0
        mov     cx, 33
        xor     dx, dx
        mov     bp, CODE
        mov     es, bp
        mov     bp, offset exitMsg
        int     10h
        mov     ah, 4Ch                 ; terminate, exit code 0FFh
        mov     al, 0FFh
        int     21h
isr_tick:
        cmp     ds:[seqBusy], 0
        jnz     isr_div
        mov     ds:[seqBusy], 1
        call    tick_spkr
        call    tick_tandy
        mov     ds:[seqBusy], 0
isr_div:
        dec     ds:[divCount]
        jnz     isr_eoi
        mov     ds:[divCount], 13       ; chain the saved handler every 13th ch0 tick
        pop     si                      ;   the BIOS handler sends its own EOI
        pop     ds
        pop     dx
        pop     bx
        pop     ax
        jmp     dword ptr cs:[oldInt8Off]
isr_eoi:
        mov     al, 20h
        out     20h, al
        pop     si
        pop     ds
        pop     dx
        pop     bx
        pop     ax
        iret

; Step the four speaker voices, then drive PIT channel 2 from the first of them
; that came out of voice_step with a level and a duration left.  One channel, so
; once spkrVoice is set the rest of the pass cannot claim it.
tick_spkr:
        mov     bx, ds:[curTune]
        cmp     bx, 0
        jz      spkr_set
        mov     ds:[spkrVoice], 0
        mov     ds:[voiceLeft], 4
        mov     si, offset spkrFreq
        mov     ds:[freqBase], si
        mov     si, offset spkrBlocks
        mov     ds:[voiceBase], si
spkr_loop:
        cmp     [si].vfDuration, 0
        jz      spkr_next
        call    voice_step
        cmp     ds:[spkrVoice], 0
        jnz     spkr_next
        cmp     [si].vfLevel, 0
        jz      spkr_next
        cmp     [si].vfDuration, 0
        jz      spkr_next
        mov     ds:[spkrVoice], si
spkr_next:
        add     si, SIZE VOICE
        dec     ds:[voiceLeft]
        jnz     spkr_loop
        mov     bl, ds:[outputOn]
        cmp     bl, 0
        jz      spkr_set
        mov     bx, ds:[spkrVoice]
        cmp     bx, 0
        jz      spkr_set
        mov     si, bx
        mov     ax, [si].vfOutPeriod
        out     42h, al
        mov     al, ah
        out     42h, al
        mov     bx, [si].vfLevel
        and     bl, 3                   ; the low two bits are the 61h gate bits
spkr_set:
        in      al, 61h
        and     al, 0FCh
        or      al, bl
        out     61h, al
        ret

; Step the four Tandy voices, then write all four to the SN76489.  DL walks the
; latch bytes 80h, 0A0h, 0C0h, 0E0h -- voice 0 to voice 2 are tone, and 0E0h is
; the noise voice, which takes no second period byte.
tick_tandy:
        mov     bx, ds:[curTune]
        cmp     bx, 0
        jz      tandy_off
        mov     ds:[voiceLeft], 4
        mov     si, offset tandyFreq
        mov     ds:[freqBase], si
        mov     si, offset tandyBlocks
        mov     ds:[voiceBase], si
tandy_loop1:
        cmp     [si].vfDuration, 0
        jz      tandy_skip1
        call    voice_step
tandy_skip1:
        add     si, SIZE VOICE
        dec     ds:[voiceLeft]
        jnz     tandy_loop1
        mov     al, ds:[outputOn]
        cmp     al, 0
        jz      tandy_off
        mov     ds:[voiceLeft], 4
        mov     si, offset tandyBlocks
        mov     dl, 80h
tandy_loop2:
        mov     ax, [si].vfOutPeriod
        shr     ax, 1                   ; AX arrives as the period shifted left 6.
        shr     ax, 1                   ;   Two shifts of AX and four of AL leave the
        shr     al, 1                   ;   low 4 period bits in AL and the high 6 in
        shr     al, 1                   ;   AH -- the chip's two bytes, in order.
        shr     al, 1
        shr     al, 1
        xor     al, dl
        out     0C0h, al
        cmp     dl, 0E0h
        jz      tandy_noatt
        mov     al, ah
        out     0C0h, al
tandy_noatt:
        mov     ax, 0FFFFh              ; the chip attenuates, so invert the level
        sub     ax, [si].vfLevel
        shr     ah, 1                   ; keep the top 4 bits of the inverted level
        shr     ah, 1
        shr     ah, 1
        shr     ah, 1
        mov     al, ah
        xor     al, dl
        add     al, 10h                 ; latch + 10h selects attenuation
        out     0C0h, al
        add     dl, 20h
        add     si, SIZE VOICE
        dec     ds:[voiceLeft]
        jnz     tandy_loop2
        ret
tandy_off:
        mov     al, 09Fh
        out     0C0h, al
        mov     al, 0BFh
        out     0C0h, al
        mov     al, 0DFh
        out     0C0h, al
        mov     al, 0FFh
        out     0C0h, al
        ret

; One tick of one voice: advance the level and pitch slides, fold in the LFO,
; resume the stream if the duration ran out, then advance the envelope.
voice_step:
        push    cx
        push    di
        mov     ax, [si].vfLevelAdd
        add     [si].vfLevel, ax
        mov     ax, [si].vfPeriodAdd
        add     [si].vfPeriod, ax
        sub     dx, dx
        mov     ax, [si].vfLfoPhase
        add     ax, [si].vfLfoRate
        jz      vs_nofreq
        cmp     ax, [si].vfLfoWrap
        jc      vs_store
        sub     ax, [si].vfLfoWrap
vs_store:
        mov     [si].vfLfoPhase, ax
        mov     cl, 4
        sar     ax, cl                  ; phase >> 4 indexes the waveform
        add     ax, [si].vfLfoTable
        mov     di, ax
        mov     ah, [di]                ; the sample goes in AH with AL zero, so the
        mov     al, 0                   ;   signed multiply leaves sample * depth / 256
        imul    [si].vfLfoDepth         ;   in DX, and DX is what the pitch picks up
vs_nofreq:
        add     dx, [si].vfPeriod
        mov     [si].vfOutPeriod, dx
        cmp     [si].vfGateLen, 0
        jz      vs_dur
        dec     [si].vfGateLen
        jnz     vs_dur
        mov     [si].vfEnvPos, 10h      ; the 5th (value,ticks) pair: the release
        mov     [si].vfEnvWait, 1
vs_dur:
        dec     [si].vfDuration
        jnz     vs_rel
        call    seq_proc
vs_rel:
        cmp     [si].vfEnvWait, 0
        jz      vs_done
        dec     [si].vfEnvWait
        jnz     vs_done
vs_relloop:
        mov     bx, [si].vfEnvBase
        add     bx, [si].vfEnvPos
        cmp     word ptr [bx+2], ENV_SETLEVEL
        jnz     vs_relset
        mov     ax, [bx]
        mov     [si].vfLevel, ax
        cmp     ax, 0
        jnz     vs_relskip
        mov     [si].vfLevelAdd, ax     ; a zero level stops the slide with it
vs_relskip:
        add     [si].vfEnvPos, 4
        jmp     vs_relloop
vs_relset:
        mov     ax, [bx]
        mov     [si].vfLevelAdd, ax
        mov     ax, [bx+2]
        mov     [si].vfEnvWait, ax
        add     [si].vfEnvPos, 4
vs_done:
        pop     di
        pop     cx
        ret

; Run this voice's stream until it yields.  DI is the stream cursor throughout.
seq_proc:
        mov     di, [si].vfStream
        cmp     di, 0
        jnz     seq_go
        ret
seq_go:
        mov     ds:[seqVoice], si
seq_loop:
        mov     bl, [di]
        inc     di
        cmp     bl, 0FAh
        jnc     seq_cmd
        jmp     seq_note
seq_cmd:
        sub     bh, bh
        sub     bl, 0FAh
        add     bl, bl
        jmp     cmdTable[bx]
seq_c_loop:                             ; 0FEh  SLOOP
        mov     bl, [di]
        inc     di
        mov     bh, 0
        mov     ax, [di]
        add     di, 2
        cmp     word ptr [bx+si], 0
        jz      seq_c_loop_set
        dec     word ptr [bx+si]
        jz      seq_loop
seq_c_loop_set:
        mov     di, ax
        jmp     seq_loop
seq_c_clear:                            ; 0FDh  SCLEAR
        mov     si, [di]
        add     di, 2
        add     si, ds:[voiceBase]
seq_c_reset:                            ; 0FAh  SRESET -- and SCLEAR's tail
        sub     bx, bx
        mov     [si].vfPeriod, bx
        mov     [si].vfPeriodAdd, bx
        mov     [si].vfOutPeriod, bx
        mov     [si].vfLevel, bx
        mov     [si].vfLevelAdd, bx
        mov     [si].vfReleaseLead, bx
        mov     [si].vfTranspose, bx
        mov     [si].vfEnvBase, bx
        mov     [si].vfEnvPos, bx
        mov     [si].vfEnvWait, bx
        mov     [si].vfLfoTable, bx
        mov     [si].vfLfoPhase, bx
        mov     [si].vfLfoRate, bx
        mov     [si].vfLfoDepth, bx
        mov     [si].vfLfoWrap, bx      ; vfDuration, vfStream, vfTempo, vfGateLen
        jmp     seq_loop                ;   and both loop counters survive a reset
seq_c_set:                              ; 0FFh  SSET
        mov     bl, [di]
        inc     di
        mov     bh, 0
        mov     ax, [di]
        inc     di
        inc     di
        mov     [bx+si], ax
        cmp     bl, 0                   ; field 0 is vfDuration, i.e. SWAIT, and a
        jnz     seq_loop                ;   SWAIT always yields
seq_end:
        mov     si, ds:[seqVoice]
        cmp     [si].vfDuration, 0
        jnz     seq_e_set
        mov     bl, 4                   ; 4 - voiceLeft is this voice's index
        sub     bl, ds:[voiceLeft]
        sub     bh, bh
        mov     voiceTune[bx], 0
        mov     di, 0
seq_e_set:
        mov     [si].vfStream, di
        ret
seq_c_ret:                              ; 0FBh  SRET
        mov     di, ds:[seqRet]
        jmp     seq_loop
seq_c_call:                             ; 0FCh  SCALL
        mov     ax, [di]
        add     di, 2
        mov     ds:[seqRet], di
        mov     di, ax
        jmp     seq_loop

; A note record: voice index and unused low bits, then the last flag and the pitch,
; then the duration.  Records run back to back until one carries the last flag.
seq_note_b:
        mov     bl, [di]
        inc     di
seq_note:
        push    di
        mov     al, bl
        mov     cl, 5
        shr     al, cl
        mov     cl, al                  ; CL = the voice this note is for
        mul     ds:[blockSize]
        add     ax, ds:[voiceBase]
        mov     di, ax                  ; DI = that voice's block
        pop     bx
        push    bx
        mov     ax, [si].vfTempo
        cmp     al, 1
        ja      sn_mul
        xor     ah, ah
        mov     al, [bx+1]
        jmp     short sn_store
sn_mul:
        mul     byte ptr [bx+1]
sn_store:
        mov     [si].vfDuration, ax
        mov     al, [bx]                ; the last flag and the pitch share this byte
        and     ax, 7Fh
        cmp     ax, REST
        jz      sn_tail
        cmp     cl, 0                   ; DI was worked out for voice CL, but only
        ja      sn_tail                 ;   voice 0 ever gets a pitch written
        mov     cx, [si].vfDuration
        mov     [di].vfDuration, cx
        mov     [di].vfGateLen, cx
        add     ax, [di].vfTranspose
        mov     [di].vfEnvPos, 0
        mov     [di].vfEnvWait, 1
        mov     cx, 0FFh                ; CL wraps to 0 on the first inc below
sn_oct:
        inc     cl
        sub     ax, OCT
        jnc     sn_oct
        add     ax, OCT                 ; CL = octave, AX = semitone
        mov     bx, ax
        add     bx, bx
        cmp     di, offset tandyVoice3  ; Both branches continue at the next instruction.
        jnz     sn_notspec
sn_notspec:
        add     bx, ds:[freqBase]
        mov     ax, [bx]
        shr     ax, cl
        mov     [di].vfPeriod, ax
        mov     [di].vfOutPeriod, ax
sn_tail:
        pop     di
        mov     al, [di]
        inc     di
        inc     di
        and     al, 80h
        jnz     sn_more
        jmp     seq_note_b
sn_more:
        jmp     seq_end

; Start a tune: clear each voice block that the tune gives a stream for, point it
; at that stream and arm it to step on the next tick.  seqBusy keeps the ISR out.
ProgramSpeakerVoices:
        push    bp
        mov     bp, sp
        push    ax
        push    bx
        push    di
        push    si
        push    ds
        mov     si, CODE
        mov     ds, si
        mov     si, [bp+6]              ; the tune id
        mov     ds:[curTune], si
        add     si, si
        add     si, si
        add     si, si                  ; * 8: four words per table row
        mov     ds:[seqBusy], 1
        mov     ds:[voiceLeft], 4
        mov     di, offset spkrBlocks
vwa_loop:
        mov     ax, songTableA[si]
        cmp     ax, 0
        jz      vwa_next
        mov     bx, SIZE VOICE - 2
vwa_clr:
        mov     word ptr [bx+di], 0
        sub     bx, 2
        jge     vwa_clr
        mov     [di].vfStream, ax
        mov     bl, 4
        sub     bl, ds:[voiceLeft]
        sub     bh, bh
        mov     ax, ds:[curTune]
        mov     voiceTune[bx], al
        mov     [di].vfDuration, 1
vwa_next:
        add     di, SIZE VOICE
        add     si, 2
        dec     ds:[voiceLeft]
        jnz     vwa_loop
        mov     ds:[seqBusy], 0
        pop     ds
        pop     si
        pop     di
        pop     bx
        pop     ax
        pop     bp
        retf    2

ProgramTandyVoices:
        push    bp
        mov     bp, sp
        push    ax
        push    bx
        push    di
        push    si
        push    ds
        mov     si, CODE
        mov     ds, si
        mov     si, [bp+6]
        mov     ds:[curTune], si
        add     si, si
        add     si, si
        add     si, si
        mov     ds:[seqBusy], 1
        mov     ds:[voiceLeft], 4
        mov     di, offset tandyBlocks
vwb_loop:
        mov     ax, songTableB[si]
        cmp     ax, 0
        jz      vwb_next
        mov     bx, SIZE VOICE - 2
vwb_clr:
        mov     word ptr [bx+di], 0
        sub     bx, 2
        jge     vwb_clr
        mov     [di].vfStream, ax
        mov     bl, 4
        sub     bl, ds:[voiceLeft]
        sub     bh, bh
        mov     ax, ds:[curTune]
        mov     voiceTune[bx], al
        mov     [di].vfDuration, 1
vwb_next:
        add     di, SIZE VOICE
        add     si, 2
        dec     ds:[voiceLeft]
        jnz     vwb_loop
        mov     ds:[seqBusy], 0
        pop     ds
        pop     si
        pop     di
        pop     bx
        pop     ax
        pop     bp
        retf    2

SetSoundOutputEnabled:
        push    bp
        mov     bp, sp
        push    ax
        push    ds
        mov     ax, CODE
        mov     ds, ax
        mov     ax, [bp+6]
        mov     ds:[outputOn], al
        pop     ds
        pop     ax
        pop     bp
        retf    2

CODE    ENDS
        END
