; Timer-driven PC-speaker and Tandy SN76489 sequencer linked by SoundDrv's {$L SOUNDDRV.OBJ}.
; Owns the voice state, tune pointer tables, streams and saved INT 8 vector in CODE.
; Pascal far entries take a Word argument where present and return with plain RETF.

CODE    SEGMENT BYTE PUBLIC             ; Leave the segment class unset so the Pascal linker can
        ASSUME  CS:CODE, DS:CODE        ; merge this object into the unit's code segment.
        PUBLIC  InstallSoundTimer, UninstallSoundTimer
        PUBLIC  ProgramSpeakerVoices, ProgramTandyVoices, SetSoundOutputEnabled

; ---------------------------------------------------------------------------
; Voice state. SSET writes fields by offset; voice_step advances them
; on each timer interrupt.
; ---------------------------------------------------------------------------
VOICE   STRUC
vfDuration      dw      0       ; ticks until the sequencer next steps this voice
vfStream        dw      0       ; stream cursor; 0 = no stream to resume
vfPeriod        dw      0       ; pitch accumulator
vfPeriodAdd     dw      0       ; added to vfPeriod each tick -- a pitch slide
vfOutPeriod     dw      0       ; vfPeriod plus the LFO; this is what the chip gets
vfLevel         dw      0       ; output level
vfLevelAdd      dw      0       ; added to vfLevel each tick
vfTempo         dw      0       ; low byte scales noteLen; a zero low byte is taken as 1
vfReleaseLead   dw      0       ; ticks the gate closes before the note ends: seq_note
                                ;   sets vfGateLen to the duration minus this
vfTranspose     dw      0       ; added to a note's pitch before the octave reduction
vfGateLen       dw      0       ; when it expires the envelope restarts at its 5th pair
vfEnvBase       dw      0       ; base of this voice's (value,ticks) envelope list
vfEnvPos        dw      0       ; byte offset into that list
vfEnvWait       dw      0       ; ticks left in the current envelope segment
vfLfoTable      dw      0       ; base of the signed-sample LFO waveform
vfLfoPhase      dw      0       ; LFO phase accumulator
vfLfoRate       dw      0       ; added to vfLfoPhase each tick
vfLfoDepth      dw      0       ; signed multiplier on the waveform sample
vfLfoWrap       dw      0       ; vfLfoPhase wraps here
vfLoopCounterA  dw      0       ; SLOOP counter
vfLoopCounterB  dw      0       ; Counter for a nested stream loop.
                dw      3 dup(0)        ; Unidentified words, cleared with the voice state.
VOICE   ENDS

; ---------------------------------------------------------------------------
; Note tables: one octave per device. seq_note selects a semitone,
; then shifts its period right by the octave number.
; ---------------------------------------------------------------------------
; PC-speaker PIT divisors, one octave starting at nominal C1.
spkC    equ 8E84h    ; C1
spkCS   equ 8684h    ; C#1
spkD    equ 7EF7h    ; D1
spkDS   equ 77D7h    ; D#1
spkE    equ 714Fh    ; E1
spkF    equ 6AC4h    ; F1
spkFS   equ 64C6h    ; F#1
spkG    equ 5F1Eh    ; G1
spkGS   equ 59C7h    ; G#1
spkA    equ 54BDh    ; A1
spkAS   equ 4FFCh    ; A#1
spkB    equ 4B7Eh    ; B1

; Tandy SN76489 periods, starting at nominal A2. Each 10-bit period is
; shifted left by six; tick_tandy shifts it back before output.
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
; Driver state.  The ISR and the voice writers reach all of it through CS.
; ---------------------------------------------------------------------------
divCount        db      13              ; ticks left before the next BIOS INT 8 chain
seqBusy         db      0               ; suppresses ISR voice work during a tune load
                                        ;   and during nested timer interrupts
voiceLeft       db      0               ; voices still to visit this pass, 4 down to 1
blockSize       db      SIZE VOICE      ; seq_note multiplies a voice index by it
SilentTune      equ     0
curTune         dw      SilentTune      ; zero bypasses voice stepping on both devices
seqVoice        dw      0               ; the voice block seq_proc is running
voiceBase       dw      0               ; block array of the device being ticked
freqBase        dw      0               ; note table of the device being ticked
seqRet          dw      0               ; the stream pointer SCALL saved -- one level only
voiceTune       db      0,0,0,0         ; tune id per voice; seq_end clears a voice's entry
                                        ;   when that voice runs out of stream
outputOn        db      1               ; zero keeps sequencing, gates the speaker off and
                                        ;   writes full attenuation to the Tandy voices

; Sparse tick multipliers indexed by the note byte AND 1Fh: the nonzero values
; alternate 2:3 and 3:4 ratios, from 2 through 64. seq_note scales the entry by
; vfTempo's low byte, treating a zero low byte as 1.
noteLen         db      000h,000h,000h,002h,000h,003h,004h,000h,006h,008h,000h,00Ch,010h,000h,018h,020h
                db      000h,030h,040h

; Sequencer command dispatch for stream bytes 0FAh through 0FFh, in that order.
; SRESET shares the clearing tail of seq_c_clear,
; skipping SCLEAR's voice selection.
cmdTable        dw      seq_c_reset, seq_c_ret, seq_c_call
                dw      seq_c_clear, seq_c_loop, seq_c_set

; Four active PC-speaker voice blocks; nonzero song pointers clear and load them.
spkrBlocks      db      000h,008h,090h,004h,000h,003h,000h,017h,000h,008h,090h,004h,000h,003h,000h,024h
                db      000h,008h,090h,004h,000h,002h,000h,02Ah,000h,008h,090h,004h,000h,000h,000h,030h
                db      000h,006h,030h,008h,000h,000h,000h,035h,000h,008h,090h,004h,000h,001h,000h,005h
                db      000h,008h,090h,004h,000h,003h,000h,00Ah,000h,008h,090h,004h,000h,002h,000h,011h
                db      000h,008h,090h,004h,000h,000h,000h,017h,000h,006h,030h,008h,000h,000h,000h,01Ch
                db      000h,000h,000h,000h,000h,000h,000h,000h,000h,004h,0E8h,00Eh,000h,000h,020h,000h
                db      000h,000h,002h,000h,002h,000h,000h,056h,000h,000h,094h,000h,000h,0A5h,000h,000h
                db      0B4h,000h,000h,0C0h,000h,000h,0CBh,000h,000h,003h,042h,004h,055h,006h,089h,0E5h
                db      002h,006h,089h,0ECh,004h,05Dh,004h,0CBh,002h,000h,002h,000h,000h,008h,000h,014h
                db      002h,006h,0B0h,001h,004h,0BAh,006h,0CEh,003h,004h,0EEh,002h,006h,0B0h,000h,004h
                db      0BAh,006h,0CFh,003h,004h,0EEh,002h,006h,0B0h,002h,004h,0BAh,006h,0CEh,003h,004h
                db      0EEh,002h,006h,0B0h,000h,004h,0BAh,006h,0CFh,003h,004h,0EEh,002h,006h,0B0h,003h

; Spare space after the four active blocks.
spkrSpare       db      004h,0BAh,006h,0CEh,003h,004h,0EEh,002h,006h,0B0h,000h,004h,0BAh,006h,0CFh,003h
                db      004h,0EEh,002h,006h,0B0h,004h,004h,0BAh,006h,0CEh,003h,004h,0EEh,002h,006h,0B0h
                db      000h,004h,0BAh,006h,0CFh,003h,004h,0EEh,002h,006h,0B0h,005h,004h,0BAh,006h,0CEh
                db      003h,004h,0EEh,002h,006h,0B0h,000h,004h,0BAh,006h,0CFh,003h,004h,0EEh,002h,006h
                db      0B0h,007h,004h,0BAh,006h,0CEh,003h,004h,0EEh,004h,030h,04Ch,000h,000h,000h,007h
                db      000h,004h,030h,048h,000h,000h,000h,00Fh,000h,004h,030h,050h,000h,000h,000h,014h
                db      000h,006h,090h,010h,000h,000h,000h,005h,000h,000h,000h,020h,000h,000h,000h,019h
                db      000h,006h,0D0h,014h,000h,016h,000h,01Dh,000h,000h,000h,008h,000h,000h,000h,021h
                db      000h,004h,030h,048h,000h,000h,000h,028h,000h,000h,000h,020h,000h,000h,000h,032h
                db      000h,000h,000h,020h,000h,000h,000h,041h,000h,006h,0D0h,014h,000h,016h,000h,04Ch
                db      000h,000h,000h,008h,000h,000h,000h,050h,000h,004h,030h,048h,000h,000h,000h,057h
                db      000h,000h,000h,014h,000h,000h,000h,05Dh,000h,006h,090h,010h,000h,000h,000h,062h

spkrFreq        dw      spkC, spkCS, spkD, spkDS, spkE, spkF
                dw      spkFS, spkG, spkGS, spkA, spkAS, spkB

spkrVoice       dw      0               ; the block driving PIT channel 2 this pass

; Four active Tandy voice blocks; nonzero song pointers clear and load them.
tandyBlocks     db      090h,010h,000h,001h,000h,007h,000h,006h,090h,010h,000h,000h,000h,00Bh,000h,000h
                db      000h,010h,000h,000h,000h,014h,000h,001h,004h,09Ah,010h,002h,030h,070h,001h,000h
                db      000h,002h,006h,083h,046h,004h,0FDh,004h,028h,002h,000h,030h,001h,000h,043h,001h
                db      002h,006h,03Bh,046h,004h,0F7h,002h,000h,052h,001h,00Ah,077h,0A7h,001h,0C8h,001h
                db      000h,000h,002h,006h,08Bh,046h,004h,0F9h,006h,03Bh,046h,004h,0F7h,002h,000h,064h
                db      001h,00Ah,075h,096h,001h,001h,002h,08Eh,001h,002h,006h,089h,046h,004h,0F9h,002h
                db      000h,0DAh,000h,000h,0D6h,000h,000h,058h,001h,000h,07Bh,001h,00Ah,0EBh,09Eh,001h
                db      0D0h,001h,05Ch,001h,00Ch,0CFh,001h,006h,0FFh,046h,004h,0F9h,00Ch,0D2h,001h,000h
                db      04Bh,001h,000h,06Fh,001h,00Ch,0FFh,001h,002h,006h,0B0h,005h,004h,0BAh,006h,0CEh
; Fourth Tandy voice.
tandyVoice3     db      003h,004h,0EEh,002h,006h,0B0h,000h,004h,0BAh,006h,0CFh,003h,004h,0EEh,002h,006h
                db      08Ah,046h,004h,0FFh,004h,0A2h,00Eh,008h,090h,008h,000h,004h,000h,002h,004h,0A0h
                db      00Eh,008h,090h,008h,000h,004h,000h,004h,050h,002h,000h,0CFh,001h,004h,00Eh,004h

; Spare space after the four active blocks.
tandySpare      db      0E8h,00Eh,000h,000h,020h,000h,000h,000h,002h,000h,002h,000h,000h,056h,000h,000h
                db      094h,000h,000h,0A5h,000h,000h,0B4h,000h,000h,0C0h,000h,000h,0CBh,000h,000h,081h
                db      001h,000h,0AAh,001h,000h,0B5h,001h,000h,0C0h,001h,000h,0DBh,001h,002h,004h,055h
                db      006h,089h,0E5h,006h,083h,0ECh,004h,00Ah,002h,006h,089h,0ECh,004h,05Dh,004h,0CAh
                db      006h,00Ch,000h,002h,000h,00Fh,002h,000h,0EAh,001h,000h,01Ah,002h,014h,00Ah,050h
                db      068h,079h,06Ch,061h,063h,074h,065h,072h,079h,000h,000h,000h,000h,000h,000h,000h
                db      000h,000h,000h,005h,050h,069h,070h,065h,073h,000h,000h,000h,000h,000h,000h,000h
                db      000h,000h,000h,000h,000h,000h,000h,000h,004h,048h,06Fh,06Ch,065h,000h,000h,000h
                db      000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,005h,054h,06Fh
                db      06Bh,065h,06Eh,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h
                db      000h,000h,004h,052h,06Fh,062h,065h,000h,000h,000h,000h,000h,000h,000h,000h,000h
                db      000h,004h,055h,006h,089h,0E5h,002h,006h,089h,0ECh,004h,05Dh,004h,0CBh,002h,000h

tandyFreq       dw      snA2, snAS2, snB2, snC3, snCS3, snD3
                dw      snDS3, snE3, snF3, snFS3, snG3, snGS3

; ---------------------------------------------------------------------------
; SONG TABLES.  One row per tune id, four stream pointers per row -- voice 0 to
; voice 3. Both ProgramSpeakerVoices and ProgramTandyVoices index by id * 8.
; A zero pointer preserves the corresponding voice block.
; ---------------------------------------------------------------------------
; Speaker output selects one voice; later streams also program other voice blocks.
songTableA      dw      silentA,    silentA,    silentA,    silentA     ; tune  0
                dw      tuneA01_v0, silentA,    silentA,    silentA     ; tune  1
                dw      tuneA02_v0, silentA,    silentA,    silentA     ; tune  2
                dw      tuneA03_v0, silentA,    silentA,    silentA     ; tune  3
                dw      tuneA04_v0, silentA,    silentA,    silentA     ; tune  4
                dw      tuneA05_v0, silentA,    silentA,    silentA     ; tune  5
                dw      tuneA06_v0, silentA,    silentA,    silentA     ; tune  6
                dw      tuneA07_v0, silentA,    silentA,    silentA     ; tune  7
                dw      tuneA08_v0, silentA,    silentA,    silentA     ; tune  8
                dw      tuneA09_v0, silentA,    silentA,    silentA     ; tune  9
                dw      tuneA10_v0, silentA,    silentA,    silentA     ; tune 10
                dw      tuneA11_v0, silentA,    silentA,    silentA     ; tune 11
                dw      tuneA12_v0, 0,          0,          0           ; tune 12
                dw      tuneA13_v0, 0,          0,          0           ; tune 13
                dw      tuneA14_v0, 0,          0,          0           ; tune 14
                dw      tuneA15_v0, 0,          0,          0           ; tune 15
                dw      tuneA16_v0, 0,          0,          0           ; tune 16
                dw      tuneA17_v0, 0,          0,          0           ; tune 17
                dw      tuneA18_v0, 0,          0,          0           ; tune 18
                dw      tuneA19_v0, 0,          0,          0           ; tune 19

; Tandy tunes use three tone voices and a noise voice.
songTableB      dw      silentB,    silentB,    silentB,    silentB     ; tune  0
                dw      tuneB01_v0, tuneB01_v1, tuneB01_v2, silentB     ; tune  1
                dw      silentB,    silentB,    silentB,    tuneB02_v3  ; tune  2
                dw      tuneB03_v0, tuneB03_v1, tuneB03_v2, silentB     ; tune  3
                dw      tuneB04_v0, silentB,    tuneB04_v2, tuneB04_v3  ; tune  4
                dw      tuneB05_v0, silentB,    silentB,    silentB     ; tune  5
                dw      silentB,    silentB,    tuneB06_v2, tuneB06_v3  ; tune  6
                dw      tuneB07_v0, tuneB07_v1, silentB,    silentB     ; tune  7
                dw      silentB,    silentB,    silentB,    tuneB08_v3  ; tune  8
                dw      silentB,    silentB,    silentB,    tuneB09_v3  ; tune  9
                dw      silentB,    silentB,    tuneB10_v2, tuneB10_v3  ; tune 10
                dw      tuneB11_v0, tuneB11_v1, tuneB11_v2, silentB     ; tune 11
                dw      tuneB12_v0, silentB,    silentB,    silentB     ; tune 12
                dw      tuneB13_v0, silentB,    silentB,    silentB     ; tune 13
                dw      tuneB14_v0, silentB,    silentB,    silentB     ; tune 14
                dw      tuneB15_v0, silentB,    silentB,    silentB     ; tune 15
                dw      tuneB16_v0, silentB,    silentB,    silentB     ; tune 16
                dw      tuneB17_v0, silentB,    silentB,    silentB     ; tune 17
                dw      tuneB18_v0, silentB,    silentB,    silentB     ; tune 18
                dw      tuneB19_v0, silentB,    silentB,    silentB     ; tune 19

; ---------------------------------------------------------------------------
; LFO WAVEFORMS.  A voice picks one by pointing vfLfoTable at it; voice_step reads
; a byte, scales it by vfLfoDepth and adds the result to the pitch going out.
; ---------------------------------------------------------------------------
; One sine cycle: 256 signed samples, amplitude 7Eh,
; approximately round(126 * sin(2*pi*i/256)).
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

; First half of the 32-sample waveform used by setupA and setupB.
lfoZero         db      000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h

; Second half of that waveform: fixed positive samples.
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
; Streams and envelope lists, referenced by song tables and sequencer commands.
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
REST    equ 7Fh                     ; no new note is programmed

; One macro per sequencer record, each emitting the record the driver decodes.
; TASM splits a macro argument list on whitespace as well as on commas, so an
; argument expression must carry none: NT_E+3*OCT, never NT_E + 3 * OCT.
SRESET  MACRO                       ;; 0FAh -- reset pitch, envelope and LFO state
        db 0FAh
        ENDM
SRET    MACRO                       ;; 0FBh -- back to the stream SCALL came from
        db 0FBh
        ENDM
SCALL   MACRO target                ;; 0FCh -- call a stream; seqRet holds one level
        db 0FCh
        dw target
        ENDM
SCLEAR  MACRO vnum                  ;; 0FDh -- select voice vnum of the active device
        db 0FDh                     ;;         and apply SRESET
        dw (vnum) * SIZE VOICE
        ENDM
SLOOP   MACRO field, target         ;; 0FEh -- zero jumps; otherwise decrement and jump if nonzero
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
SNOTE   MACRO vnum, len, pitch, last  ;; a note: voice, noteLen index, pitch, run-end
        db ((vnum) SHL 5) OR (len), ((last) SHL 7) OR (pitch)
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
        SLOOP   vfLoopCounterA,  tuneA07_v0_loop
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
tuneA05_v0_loop:
        SSET    vfPeriodAdd,     0
        SWAIT   6
        SSET    vfLoopCounterB,  12
; Nested stream loop: vfLoopCounterB counts this inner loop;
; tuneA05_v0_loop uses vfLoopCounterA for the outer loop.
tuneA05_v0_inner:
        SSET    vfPeriodAdd,     0FC5Eh
        SWAIT   1
        SSET    vfPeriodAdd,     384h
        SWAIT   1
        SLOOP   vfLoopCounterB,  tuneA05_v0_inner
        SLOOP   vfLoopCounterA,  tuneA05_v0_loop
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
        SLOOP   vfLoopCounterA,  tuneA03_v0_loop
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
        SLOOP   vfLoopCounterA,  tuneA04_v0_loop
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
; Empty stream: silence the voice and stop.
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
        SLOOP   vfLoopCounterA,  tuneA01_v0_loop
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
tuneA12_v0:
        SCALL   setupA
        SNOTE   2, 12, NT_C+6*OCT,  1
        SNOTE   2,  9, NT_DS+6*OCT, 1
        SNOTE   2, 17, NT_G+6*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   1,  6, NT_DS+5*OCT, 0
        SNOTE   0,  6, NT_C+4*OCT,  1
        SNOTE   1,  6, NT_DS+5*OCT, 0
        SNOTE   0,  6, NT_C+4*OCT,  1
        SNOTE   1, 17, NT_DS+5*OCT, 0
        SNOTE   0, 17, NT_C+4*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   2,  9, NT_G+6*OCT,  1
        SNOTE   2,  9, NT_F+6*OCT,  1
        SNOTE   2,  9, NT_DS+6*OCT, 1
        SNOTE   2, 12, NT_F+6*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  1
        SNOTE   2, 17, NT_AS+6*OCT, 0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   1,  6, NT_D+5*OCT,  0
        SNOTE   0,  6, NT_AS+3*OCT, 1
        SNOTE   1,  6, NT_D+5*OCT,  0
        SNOTE   0,  6, NT_AS+3*OCT, 1
        SNOTE   0, 15, NT_AS+3*OCT, 0
        SNOTE   1, 15, NT_D+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   2,  9, NT_D+7*OCT,  1
        SNOTE   2,  9, NT_C+7*OCT,  1
        SNOTE   2,  9, NT_AS+6*OCT, 0
        SNOTE   1,  6, NT_F+5*OCT,  0
        SNOTE   0,  6, NT_AS+3*OCT, 1
        SNOTE   1,  6, NT_F+5*OCT,  0
        SNOTE   0,  6, NT_AS+3*OCT, 1
        SNOTE   0, 12, NT_A+3*OCT,  0
        SNOTE   1, 12, NT_F+5*OCT,  0
        SNOTE   2,  9, NT_C+7*OCT,  1
        SNOTE   2,  9, NT_A+6*OCT,  1
        SNOTE   2,  9, NT_F+6*OCT,  0
        SNOTE   1,  6, NT_F+5*OCT,  0
        SNOTE   0,  6, NT_A+3*OCT,  1
        SNOTE   1,  6, NT_F+5*OCT,  0
        SNOTE   0,  6, NT_A+3*OCT,  1
        SNOTE   2, 17, NT_G+6*OCT,  0
        SNOTE   1, 12, NT_D+5*OCT,  0
        SNOTE   0, 12, NT_G+3*OCT,  1
        SNOTE   1,  6, NT_G+5*OCT,  0
        SNOTE   0,  6, NT_G+3*OCT,  1
        SNOTE   1,  6, NT_G+5*OCT,  0
        SNOTE   0,  6, NT_G+3*OCT,  1
        SNOTE   0, 14, NT_G+3*OCT,  0
        SNOTE   1, 14, NT_D+5*OCT,  1
        SNOTE   2, 12, NT_GS+6*OCT, 1
        SNOTE   2,  9, NT_C+7*OCT,  1
        SNOTE   2, 17, NT_DS+7*OCT, 0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_GS+3*OCT, 0
        SNOTE   1,  6, NT_C+5*OCT,  1
        SNOTE   1,  6, NT_C+5*OCT,  0
        SNOTE   0,  6, NT_GS+3*OCT, 1
        SNOTE   0, 15, NT_GS+3*OCT, 0
        SNOTE   1, 15, NT_C+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   2,  9, NT_F+7*OCT,  1
        SNOTE   2,  9, NT_DS+7*OCT, 1
        SNOTE   2,  9, NT_CS+7*OCT, 0
        SNOTE   1,  6, NT_F+5*OCT,  0
        SNOTE   0,  6, NT_CS+4*OCT, 1
        SNOTE   1,  6, NT_F+5*OCT,  0
        SNOTE   0,  6, NT_CS+4*OCT, 1
        SNOTE   2, 12, NT_DS+7*OCT, 0
        SNOTE   0, 12, NT_CS+4*OCT, 0
        SNOTE   1, 12, NT_F+5*OCT,  1
        SNOTE   2,  9, NT_C+7*OCT,  0
        SNOTE   0,  6, NT_GS+3*OCT, 0
        SNOTE   1,  6, NT_C+5*OCT,  1
        SNOTE   1,  6, NT_C+5*OCT,  0
        SNOTE   0,  6, NT_GS+3*OCT, 1
        SNOTE   2, 17, NT_GS+6*OCT, 0
        SNOTE   1, 12, NT_C+5*OCT,  0
        SNOTE   0, 12, NT_GS+3*OCT, 1
        SNOTE   0,  6, NT_GS+3*OCT, 0
        SNOTE   1,  6, NT_C+5*OCT,  1
        SNOTE   1,  6, NT_C+5*OCT,  0
        SNOTE   0,  6, NT_GS+3*OCT, 1
        SNOTE   1, 15, NT_C+5*OCT,  0
        SNOTE   0, 15, NT_GS+3*OCT, 0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   2,  9, NT_F+7*OCT,  1
        SNOTE   2,  9, NT_DS+7*OCT, 1
        SNOTE   2,  9, NT_CS+7*OCT, 0
        SNOTE   1,  6, NT_F+5*OCT,  0
        SNOTE   0,  6, NT_CS+4*OCT, 1
        SNOTE   1,  6, NT_F+5*OCT,  0
        SNOTE   0,  6, NT_CS+4*OCT, 1
        SNOTE   1, 12, NT_DS+5*OCT, 0
        SNOTE   0, 12, NT_GS+4*OCT, 0
        SNOTE   2,  9, NT_DS+7*OCT, 1
        SNOTE   2,  9, NT_C+7*OCT,  1
        SNOTE   2,  9, NT_GS+6*OCT, 0
        SNOTE   0,  6, NT_GS+4*OCT, 0
        SNOTE   1,  6, NT_DS+5*OCT, 1
        SNOTE   1,  6, NT_DS+5*OCT, 0
        SNOTE   0,  6, NT_GS+4*OCT, 1
        SNOTE   1, 12, NT_F+5*OCT,  0
        SNOTE   0, 12, NT_CS+4*OCT, 0
        SNOTE   2,  9, NT_F+7*OCT,  1
        SNOTE   2,  9, NT_DS+7*OCT, 1
        SNOTE   2,  9, NT_CS+7*OCT, 0
        SNOTE   0,  6, NT_CS+4*OCT, 0
        SNOTE   1,  6, NT_F+5*OCT,  1
        SNOTE   1,  6, NT_F+5*OCT,  0
        SNOTE   0,  6, NT_CS+4*OCT, 1
        SNOTE   1, 12, NT_DS+5*OCT, 0
        SNOTE   0, 12, NT_GS+4*OCT, 0
        SNOTE   2,  9, NT_DS+7*OCT, 1
        SNOTE   2,  9, NT_C+7*OCT,  1
        SNOTE   2,  9, NT_GS+6*OCT, 1
        SNOTE   2, 17, NT_G+6*OCT,  0
        SNOTE   0, 12, REST,        1
        SNOTE   0,  6, NT_G+3*OCT,  0
        SNOTE   1,  6, NT_G+5*OCT,  1
        SNOTE   1,  6, NT_G+5*OCT,  0
        SNOTE   0,  6, NT_G+3*OCT,  1
        SNOTE   0, 14, NT_G+3*OCT,  0
        SNOTE   1, 14, NT_G+5*OCT,  1
        SNOTE   2,  9, NT_D+7*OCT,  1
        SNOTE   2,  9, NT_B+6*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  1
        SNOTE   2, 17, NT_G+6*OCT,  0
        SNOTE   0, 12, REST,        1
        SNOTE   0,  6, NT_G+3*OCT,  0
        SNOTE   1,  6, NT_G+5*OCT,  1
        SNOTE   1,  6, NT_G+5*OCT,  0
        SNOTE   0,  6, NT_G+3*OCT,  1
        SNOTE   0, 14, NT_G+3*OCT,  0
        SNOTE   1, 14, NT_G+5*OCT,  1
        SNOTE   2, 11, NT_G+6*OCT,  0
        SNOTE   0,  9, REST,        1
        SNOTE   1,  6, NT_DS+5*OCT, 0
        SNOTE   0,  6, NT_C+4*OCT,  1
        SNOTE   2,  6, NT_DS+6*OCT, 0
        SNOTE   1,  6, NT_DS+5*OCT, 0
        SNOTE   0,  6, NT_C+5*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 0
        SNOTE   0,  9, NT_C+4*OCT,  1
        SNOTE   2, 11, NT_G+6*OCT,  0
        SNOTE   0,  9, REST,        1
        SNOTE   1,  6, NT_DS+5*OCT, 0
        SNOTE   0,  6, NT_C+4*OCT,  1
        SNOTE   2,  6, NT_DS+6*OCT, 0
        SNOTE   1,  6, NT_DS+5*OCT, 0
        SNOTE   0,  6, NT_C+5*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 0
        SNOTE   0,  9, NT_C+4*OCT,  1
        SNOTE   2,  9, NT_C+6*OCT,  1
        SNOTE   2,  9, NT_F+6*OCT,  0
        SNOTE   1,  6, NT_C+5*OCT,  0
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  0
        SNOTE   1,  6, NT_C+5*OCT,  1
        SNOTE   2,  9, NT_GS+6*OCT, 0
        SNOTE   0,  9, NT_F+4*OCT,  0
        SNOTE   1,  9, NT_C+5*OCT,  1
        SNOTE   2, 11, NT_G+6*OCT,  0
        SNOTE   0,  9, REST,        1
        SNOTE   1,  6, NT_DS+5*OCT, 0
        SNOTE   0,  6, NT_C+4*OCT,  1
        SNOTE   2,  6, NT_DS+6*OCT, 0
        SNOTE   1,  6, NT_DS+5*OCT, 0
        SNOTE   0,  6, NT_C+5*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 0
        SNOTE   0,  9, NT_C+4*OCT,  1
        SNOTE   2, 11, NT_G+6*OCT,  0
        SNOTE   0,  9, REST,        1
        SNOTE   1,  6, NT_DS+5*OCT, 0
        SNOTE   0,  6, NT_C+4*OCT,  1
        SNOTE   2,  6, NT_DS+6*OCT, 0
        SNOTE   1,  6, NT_DS+5*OCT, 0
        SNOTE   0,  6, NT_C+5*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 0
        SNOTE   0,  9, NT_C+4*OCT,  1
        SNOTE   2,  9, NT_C+7*OCT,  1
        SNOTE   2,  9, NT_F+7*OCT,  0
        SNOTE   1,  6, NT_C+5*OCT,  0
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  0
        SNOTE   1,  6, NT_C+5*OCT,  1
        SNOTE   0,  9, NT_F+4*OCT,  0
        SNOTE   2,  9, NT_GS+7*OCT, 0
        SNOTE   1,  9, NT_C+5*OCT,  1
tuneA13_v0:
        SCALL   setupA
        SNOTE   0,  6, NT_G+3*OCT,  1
        SNOTE   0,  6, NT_F+3*OCT,  1
        SNOTE   0,  6, NT_G+3*OCT,  1
        SNOTE   0,  6, NT_F+3*OCT,  1
        SNOTE   0,  6, NT_G+3*OCT,  1
        SNOTE   0,  6, NT_F+3*OCT,  1
        SNOTE   0,  6, NT_GS+3*OCT, 1
        SNOTE   0,  6, NT_AS+3*OCT, 1
        SNOTE   0,  6, NT_C+4*OCT,  1
        SNOTE   0,  6, NT_D+4*OCT,  1
        SNOTE   0,  6, NT_DS+4*OCT, 1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   0,  6, NT_GS+4*OCT, 1
        SNOTE   0,  6, NT_AS+4*OCT, 1
        SNOTE   0,  6, NT_C+5*OCT,  1
        SNOTE   0,  6, NT_D+5*OCT,  1
        SNOTE   0,  6, NT_DS+5*OCT, 1
        SNOTE   0,  6, NT_F+5*OCT,  1
        SNOTE   2, 17, NT_D+6*OCT,  0
        SNOTE   1, 17, NT_C+6*OCT,  0
        SNOTE   0,  6, NT_G+3*OCT,  1
        SNOTE   0,  6, NT_F+3*OCT,  1
        SNOTE   0,  6, NT_G+3*OCT,  1
        SNOTE   0,  6, NT_F+3*OCT,  1
        SNOTE   0,  6, NT_G+3*OCT,  1
        SNOTE   0,  6, NT_F+3*OCT,  1
        SNOTE   0,  6, NT_GS+3*OCT, 1
        SNOTE   0,  6, NT_AS+3*OCT, 1
        SNOTE   0,  6, NT_C+4*OCT,  1
        SNOTE   0,  6, NT_D+4*OCT,  1
        SNOTE   0,  6, NT_DS+4*OCT, 1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   2, 17, NT_D+6*OCT,  0
        SNOTE   1, 17, NT_B+5*OCT,  0
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   0,  6, NT_GS+4*OCT, 1
        SNOTE   0,  6, NT_AS+4*OCT, 1
        SNOTE   0,  6, NT_C+5*OCT,  1
        SNOTE   0,  6, NT_D+5*OCT,  1
        SNOTE   0,  6, NT_DS+5*OCT, 1
        SNOTE   0,  6, NT_F+5*OCT,  1
        SNOTE   2, 11, NT_D+6*OCT,  0
        SNOTE   1, 11, NT_C+6*OCT,  0
        SNOTE   0,  6, NT_G+3*OCT,  1
        SNOTE   0,  6, NT_F+3*OCT,  1
        SNOTE   0,  6, NT_G+3*OCT,  1
        SNOTE   0,  6, NT_F+3*OCT,  0
        SNOTE   2,  6, NT_D+6*OCT,  0
        SNOTE   1,  6, NT_C+6*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   0,  6, NT_G+3*OCT,  1
        SNOTE   0,  6, NT_F+3*OCT,  1
        SNOTE   2, 11, NT_D+6*OCT,  0
        SNOTE   1, 11, NT_C+6*OCT,  0
        SNOTE   0,  6, NT_GS+3*OCT, 1
        SNOTE   0,  6, NT_AS+3*OCT, 1
        SNOTE   0,  6, NT_C+4*OCT,  1
        SNOTE   0,  6, NT_D+4*OCT,  0
        SNOTE   2,  6, NT_D+6*OCT,  0
        SNOTE   1,  6, NT_C+6*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   0,  6, NT_DS+4*OCT, 1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   2, 11, NT_D+6*OCT,  0
        SNOTE   1, 11, NT_B+5*OCT,  0
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  0
        SNOTE   2,  6, NT_D+6*OCT,  0
        SNOTE   1,  6, NT_B+5*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  0
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   2, 11, NT_D+6*OCT,  0
        SNOTE   1, 11, NT_B+5*OCT,  0
        SNOTE   0,  6, NT_GS+4*OCT, 1
        SNOTE   0,  6, NT_AS+4*OCT, 1
        SNOTE   0,  6, NT_C+5*OCT,  1
        SNOTE   0,  6, NT_D+5*OCT,  0
        SNOTE   2,  6, NT_D+6*OCT,  0
        SNOTE   1,  6, NT_B+5*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  0
        SNOTE   0,  6, NT_DS+5*OCT, 1
        SNOTE   0,  6, NT_F+5*OCT,  1
        SNOTE   2, 11, NT_D+6*OCT,  0
        SNOTE   1, 11, NT_C+6*OCT,  0
        SNOTE   0,  6, NT_G+3*OCT,  1
        SNOTE   0,  6, NT_F+3*OCT,  1
        SNOTE   0,  6, NT_G+3*OCT,  1
        SNOTE   0,  6, NT_F+3*OCT,  0
        SNOTE   2,  6, NT_D+6*OCT,  0
        SNOTE   1,  6, NT_C+6*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   0,  6, NT_G+3*OCT,  1
        SNOTE   0,  6, NT_F+3*OCT,  1
        SNOTE   2, 11, NT_D+6*OCT,  0
        SNOTE   1, 11, NT_C+6*OCT,  0
        SNOTE   0,  6, NT_GS+3*OCT, 1
        SNOTE   0,  6, NT_AS+3*OCT, 1
        SNOTE   0,  6, NT_C+4*OCT,  1
        SNOTE   0,  6, NT_D+4*OCT,  0
        SNOTE   2,  6, NT_D+6*OCT,  0
        SNOTE   1,  6, NT_C+6*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   0,  6, NT_DS+4*OCT, 1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   2, 11, NT_D+6*OCT,  0
        SNOTE   1, 11, NT_B+5*OCT,  0
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  0
        SNOTE   2,  6, NT_D+6*OCT,  0
        SNOTE   1,  6, NT_B+5*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  0
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   2, 11, NT_D+6*OCT,  0
        SNOTE   1, 11, NT_B+5*OCT,  0
        SNOTE   0,  6, NT_GS+4*OCT, 1
        SNOTE   0,  6, NT_AS+4*OCT, 1
        SNOTE   0,  6, NT_C+5*OCT,  1
        SNOTE   0,  6, NT_D+5*OCT,  0
        SNOTE   2,  6, NT_D+6*OCT,  0
        SNOTE   1,  6, NT_B+5*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  0
        SNOTE   0,  6, NT_DS+5*OCT, 1
        SNOTE   0,  6, NT_F+5*OCT,  1
tuneA14_v0:
        SCALL   setupA
        SNOTE   2, 12, NT_C+6*OCT,  0
        SNOTE   0, 11, NT_C+3*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 1
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_C+4*OCT,  1
        SNOTE   0,  9, NT_C+3*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_DS+6*OCT, 1
        SNOTE   2, 17, NT_G+6*OCT,  0
        SNOTE   0, 11, NT_C+3*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 1
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_C+4*OCT,  1
        SNOTE   0,  9, NT_C+3*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   0, 11, NT_C+3*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 1
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_C+4*OCT,  1
        SNOTE   0,  9, NT_C+3*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   0, 11, NT_C+3*OCT,  0
        SNOTE   2,  9, NT_G+6*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 1
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   2,  9, NT_F+6*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_C+4*OCT,  1
        SNOTE   0,  9, NT_C+3*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_DS+6*OCT, 1
        SNOTE   2, 12, NT_F+6*OCT,  0
        SNOTE   0, 11, NT_AS+3*OCT, 0
        SNOTE   1,  9, NT_D+5*OCT,  1
        SNOTE   1,  9, NT_F+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_AS+4*OCT, 1
        SNOTE   0,  9, NT_AS+3*OCT, 0
        SNOTE   1,  9, NT_AS+5*OCT, 0
        SNOTE   2,  9, NT_D+6*OCT,  1
        SNOTE   2, 17, NT_AS+6*OCT, 0
        SNOTE   0, 11, NT_AS+3*OCT, 0
        SNOTE   1,  9, NT_D+5*OCT,  1
        SNOTE   1,  9, NT_F+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_AS+4*OCT, 1
        SNOTE   0,  9, NT_AS+3*OCT, 0
        SNOTE   1,  9, NT_AS+5*OCT, 1
        SNOTE   0, 11, NT_AS+3*OCT, 0
        SNOTE   1,  9, NT_D+5*OCT,  1
        SNOTE   1,  9, NT_F+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_AS+4*OCT, 1
        SNOTE   0,  9, NT_AS+3*OCT, 0
        SNOTE   1,  9, NT_AS+5*OCT, 1
        SNOTE   0, 11, NT_AS+3*OCT, 0
        SNOTE   2,  9, NT_D+7*OCT,  0
        SNOTE   1,  9, NT_D+5*OCT,  1
        SNOTE   1,  9, NT_F+5*OCT,  0
        SNOTE   2,  9, NT_C+7*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_AS+4*OCT, 1
        SNOTE   0,  9, NT_AS+3*OCT, 0
        SNOTE   1,  9, NT_AS+5*OCT, 0
        SNOTE   2,  9, NT_AS+6*OCT, 1
        SNOTE   0, 11, NT_A+3*OCT,  0
        SNOTE   2,  9, NT_C+7*OCT,  0
        SNOTE   1,  9, NT_A+5*OCT,  1
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_A+6*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_A+4*OCT,  1
        SNOTE   0,  9, NT_A+3*OCT,  0
        SNOTE   1,  9, NT_A+5*OCT,  0
        SNOTE   2,  9, NT_F+6*OCT,  1
        SNOTE   2, 17, NT_G+6*OCT,  0
        SNOTE   0, 11, NT_G+3*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   1,  9, NT_DS+6*OCT, 0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  9, NT_G+3*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   0, 11, NT_G+3*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   1,  9, NT_DS+6*OCT, 0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  9, NT_G+3*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   2, 17, NT_G+6*OCT,  0
        SNOTE   0, 11, NT_G+3*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   1,  9, NT_D+6*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  9, NT_G+3*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   0, 11, NT_G+3*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   1,  9, NT_D+6*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  9, NT_G+3*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   2, 12, NT_GS+6*OCT, 0
        SNOTE   0, 11, NT_GS+3*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   1,  9, NT_DS+6*OCT, 0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_GS+4*OCT, 1
        SNOTE   0,  9, NT_GS+3*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_C+7*OCT,  1
        SNOTE   2, 17, NT_DS+7*OCT, 0
        SNOTE   0, 11, NT_GS+3*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   1,  9, NT_DS+6*OCT, 0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_GS+4*OCT, 1
        SNOTE   0,  9, NT_GS+3*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   0, 11, NT_GS+3*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   1,  9, NT_DS+6*OCT, 0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_GS+4*OCT, 1
        SNOTE   0,  9, NT_GS+3*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   0,  9, NT_CS+3*OCT, 0
        SNOTE   1,  9, NT_F+5*OCT,  0
        SNOTE   2,  9, NT_F+7*OCT,  1
        SNOTE   0,  9, NT_F+3*OCT,  0
        SNOTE   1,  9, NT_GS+5*OCT, 0
        SNOTE   2,  9, NT_DS+7*OCT, 1
        SNOTE   0,  9, NT_GS+3*OCT, 0
        SNOTE   1,  9, NT_CS+6*OCT, 0
        SNOTE   2,  9, NT_CS+7*OCT, 1
        SNOTE   2, 12, NT_DS+7*OCT, 0
        SNOTE   0, 11, NT_GS+3*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   1,  9, NT_DS+6*OCT, 0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_GS+4*OCT, 1
        SNOTE   0,  9, NT_GS+3*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_C+7*OCT,  1
        SNOTE   2, 17, NT_GS+6*OCT, 0
        SNOTE   0, 11, NT_GS+3*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   1,  9, NT_DS+6*OCT, 0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_GS+4*OCT, 1
        SNOTE   0,  9, NT_GS+3*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   0, 11, NT_GS+3*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   1,  9, NT_DS+6*OCT, 0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_GS+4*OCT, 1
        SNOTE   0,  9, NT_GS+3*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   0,  9, NT_CS+3*OCT, 0
        SNOTE   1,  9, NT_F+5*OCT,  0
        SNOTE   2,  9, NT_F+7*OCT,  1
        SNOTE   0,  9, NT_F+3*OCT,  0
        SNOTE   1,  9, NT_GS+5*OCT, 0
        SNOTE   2,  9, NT_DS+7*OCT, 1
        SNOTE   0,  9, NT_GS+3*OCT, 0
        SNOTE   1,  9, NT_CS+6*OCT, 0
        SNOTE   2,  9, NT_CS+7*OCT, 1
        SNOTE   0, 11, NT_GS+3*OCT, 0
        SNOTE   2,  9, NT_DS+7*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   1,  9, NT_DS+6*OCT, 0
        SNOTE   2,  9, NT_C+7*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_GS+4*OCT, 1
        SNOTE   0,  9, NT_GS+3*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_GS+6*OCT, 1
        SNOTE   0,  9, NT_CS+3*OCT, 0
        SNOTE   1,  9, NT_F+5*OCT,  0
        SNOTE   2,  9, NT_F+7*OCT,  1
        SNOTE   0,  9, NT_F+3*OCT,  0
        SNOTE   1,  9, NT_GS+5*OCT, 0
        SNOTE   2,  9, NT_DS+7*OCT, 1
        SNOTE   0,  9, NT_GS+3*OCT, 0
        SNOTE   1,  9, NT_CS+6*OCT, 0
        SNOTE   2,  9, NT_CS+7*OCT, 1
        SNOTE   0, 11, NT_G+3*OCT,  0
        SNOTE   2,  9, NT_DS+7*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   1,  9, NT_DS+6*OCT, 0
        SNOTE   2,  9, NT_C+7*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  9, NT_G+3*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_GS+6*OCT, 1
        SNOTE   2, 17, NT_G+6*OCT,  0
        SNOTE   0, 11, NT_G+3*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   1,  9, NT_DS+6*OCT, 0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  9, NT_G+3*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   0, 11, NT_G+3*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   1,  9, NT_DS+6*OCT, 0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  9, NT_G+3*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   0, 11, NT_G+3*OCT,  0
        SNOTE   2,  9, NT_D+7*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   1,  9, NT_D+6*OCT,  0
        SNOTE   2,  9, NT_B+6*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  9, NT_G+3*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  0
        SNOTE   2,  9, NT_G+6*OCT,  1
        SNOTE   2, 17, NT_G+6*OCT,  0
        SNOTE   0, 11, NT_G+3*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   1,  9, NT_D+6*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  9, NT_G+3*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   0, 11, NT_G+3*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   1,  9, NT_D+6*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  9, NT_G+3*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
tuneA15_v0:
        SCALL   setupA
        SNOTE   0, 11, NT_C+3*OCT,  0
        SNOTE   2, 11, NT_G+6*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 1
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_C+4*OCT,  0
        SNOTE   2,  6, NT_DS+6*OCT, 1
        SNOTE   0,  9, NT_C+3*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_G+6*OCT,  1
        SNOTE   0, 11, NT_C+3*OCT,  0
        SNOTE   2, 11, NT_G+6*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 1
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_C+4*OCT,  0
        SNOTE   2,  6, NT_DS+6*OCT, 1
        SNOTE   0,  9, NT_C+3*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_G+6*OCT,  1
        SNOTE   0,  9, NT_F+3*OCT,  0
        SNOTE   1,  9, NT_GS+5*OCT, 0
        SNOTE   2,  9, NT_C+6*OCT,  1
        SNOTE   0,  9, NT_GS+3*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_F+6*OCT,  1
        SNOTE   0,  9, NT_C+4*OCT,  0
        SNOTE   1,  9, NT_F+6*OCT,  0
        SNOTE   2,  9, NT_GS+6*OCT, 1
        SNOTE   0, 11, NT_C+3*OCT,  0
        SNOTE   2, 11, NT_G+6*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 1
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_C+4*OCT,  0
        SNOTE   2,  6, NT_DS+6*OCT, 1
        SNOTE   0,  9, NT_C+3*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_G+6*OCT,  1
        SNOTE   0, 11, NT_C+3*OCT,  0
        SNOTE   2, 11, NT_G+6*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 1
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_C+4*OCT,  0
        SNOTE   2,  6, NT_DS+6*OCT, 1
        SNOTE   0,  9, NT_C+3*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_G+6*OCT,  1
        SNOTE   0,  9, NT_F+3*OCT,  0
        SNOTE   1,  9, NT_GS+5*OCT, 0
        SNOTE   2,  9, NT_C+7*OCT,  1
        SNOTE   0,  9, NT_GS+3*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_F+7*OCT,  1
        SNOTE   0,  9, NT_C+4*OCT,  0
        SNOTE   1,  9, NT_F+6*OCT,  0
        SNOTE   2,  9, NT_GS+7*OCT, 1
        SNOTE   0, 11, NT_C+3*OCT,  0
        SNOTE   2, 11, NT_G+6*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 1
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_C+4*OCT,  0
        SNOTE   2,  6, NT_DS+6*OCT, 1
        SNOTE   0,  9, NT_C+3*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_G+6*OCT,  1
        SNOTE   0, 11, NT_C+3*OCT,  0
        SNOTE   2, 11, NT_G+6*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 1
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_C+4*OCT,  0
        SNOTE   2,  6, NT_DS+6*OCT, 1
        SNOTE   0,  9, NT_C+3*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_G+6*OCT,  1
        SNOTE   0,  9, NT_F+3*OCT,  0
        SNOTE   1,  9, NT_A+5*OCT,  0
        SNOTE   2,  9, NT_C+7*OCT,  1
        SNOTE   0,  9, NT_A+3*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_F+7*OCT,  1
        SNOTE   0,  9, NT_C+4*OCT,  0
        SNOTE   1,  9, NT_F+6*OCT,  0
        SNOTE   2,  9, NT_GS+7*OCT, 1
        SNOTE   1, 17, NT_C+6*OCT,  0
        SNOTE   2, 17, NT_GS+7*OCT, 0
        SNOTE   0, 12, NT_GS+3*OCT, 1
        SNOTE   0,  9, NT_GS+3*OCT, 1
        SNOTE   0, 12, NT_GS+3*OCT, 1
        SNOTE   0,  9, NT_GS+3*OCT, 1
        SNOTE   0, 12, NT_GS+3*OCT, 1
tuneA16_v0:
        SCALL   setupA
        SNOTE   0,  9, NT_GS+3*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_DS+6*OCT, 1
        SNOTE   0, 12, NT_GS+3*OCT, 0
        SNOTE   2, 11, NT_E+6*OCT,  0
        SNOTE   1, 11, NT_CS+6*OCT, 1
        SNOTE   2,  6, NT_FS+6*OCT, 1
        SNOTE   0,  9, NT_GS+3*OCT, 0
        SNOTE   1,  9, NT_CS+6*OCT, 0
        SNOTE   2,  9, NT_GS+6*OCT, 1
        SNOTE   1, 15, NT_C+6*OCT,  0
        SNOTE   2, 15, NT_DS+6*OCT, 0
        SNOTE   0, 12, NT_GS+3*OCT, 1
        SNOTE   0,  9, NT_GS+3*OCT, 1
        SNOTE   0, 12, NT_GS+3*OCT, 1
        SNOTE   0,  9, NT_GS+3*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_DS+6*OCT, 1
        SNOTE   0, 12, NT_GS+3*OCT, 0
        SNOTE   2, 11, NT_E+6*OCT,  0
        SNOTE   1, 11, NT_CS+6*OCT, 1
        SNOTE   2,  6, NT_FS+6*OCT, 1
        SNOTE   0,  9, NT_GS+3*OCT, 0
        SNOTE   1,  9, NT_CS+6*OCT, 0
        SNOTE   2,  9, NT_GS+6*OCT, 1
        SNOTE   1, 14, NT_DS+6*OCT, 0
        SNOTE   0, 11, NT_B+3*OCT,  0
        SNOTE   2,  9, NT_FS+6*OCT, 1
        SNOTE   2,  9, NT_B+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_CS+4*OCT, 1
        SNOTE   2,  9, NT_B+6*OCT,  0
        SNOTE   0,  9, NT_DS+4*OCT, 1
        SNOTE   0, 14, NT_E+4*OCT,  0
        SNOTE   1, 14, NT_B+5*OCT,  0
        SNOTE   2, 11, NT_GS+6*OCT, 1
        SNOTE   2,  6, NT_FS+6*OCT, 1
        SNOTE   2,  9, NT_E+6*OCT,  1
        SNOTE   0, 14, NT_C+4*OCT,  0
        SNOTE   2,  9, NT_G+6*OCT,  0
        SNOTE   1,  9, NT_E+6*OCT,  1
        SNOTE   1,  9, NT_D+6*OCT,  0
        SNOTE   2,  9, NT_FS+6*OCT, 1
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_E+6*OCT,  1
        SNOTE   0, 14, NT_B+3*OCT,  0
        SNOTE   2,  9, NT_D+6*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   2,  9, NT_B+5*OCT,  1
        SNOTE   1,  9, NT_D+5*OCT,  0
        SNOTE   2,  9, NT_G+5*OCT,  1
        SNOTE   1, 15, NT_CS+6*OCT, 0
        SNOTE   2, 15, NT_E+6*OCT,  0
        SNOTE   0, 12, NT_A+3*OCT,  1
        SNOTE   0,  9, NT_A+3*OCT,  1
        SNOTE   0, 12, NT_A+3*OCT,  1
        SNOTE   0,  9, NT_A+3*OCT,  0
        SNOTE   1,  9, NT_CS+6*OCT, 0
        SNOTE   2,  9, NT_E+6*OCT,  1
        SNOTE   0, 12, NT_A+3*OCT,  0
        SNOTE   2, 11, NT_F+6*OCT,  0
        SNOTE   1, 11, NT_D+6*OCT,  1
        SNOTE   2,  6, NT_G+6*OCT,  1
        SNOTE   2,  9, NT_A+6*OCT,  0
        SNOTE   0,  9, NT_A+3*OCT,  1
        SNOTE   1, 15, NT_CS+6*OCT, 0
        SNOTE   2, 15, NT_E+6*OCT,  0
        SNOTE   0, 12, NT_A+3*OCT,  1
        SNOTE   0,  9, NT_A+3*OCT,  1
        SNOTE   0, 12, NT_A+3*OCT,  1
        SNOTE   0,  9, NT_A+3*OCT,  0
        SNOTE   1,  9, NT_CS+6*OCT, 0
        SNOTE   2,  9, NT_E+6*OCT,  1
        SNOTE   1, 11, NT_D+6*OCT,  0
        SNOTE   2, 11, NT_F+6*OCT,  0
        SNOTE   0,  9, NT_D+4*OCT,  1
        SNOTE   0,  9, NT_C+4*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   2,  6, NT_G+6*OCT,  1
        SNOTE   2,  9, NT_A+6*OCT,  0
        SNOTE   0,  9, NT_AS+3*OCT, 1
        SNOTE   2, 15, NT_E+6*OCT,  0
        SNOTE   1, 15, NT_CS+6*OCT, 0
        SNOTE   0, 12, NT_A+3*OCT,  1
        SNOTE   0,  9, NT_A+3*OCT,  1
        SNOTE   0, 12, NT_A+3*OCT,  1
        SNOTE   0,  9, NT_A+3*OCT,  0
        SNOTE   1,  9, NT_CS+6*OCT, 0
        SNOTE   2,  9, NT_E+6*OCT,  1
        SNOTE   0, 14, NT_G+3*OCT,  0
        SNOTE   1, 11, NT_D+6*OCT,  0
        SNOTE   2,  9, NT_FS+6*OCT, 1
        SNOTE   2,  9, NT_A+6*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   1,  6, NT_B+5*OCT,  1
        SNOTE   1,  9, NT_A+5*OCT,  0
        SNOTE   2,  9, NT_FS+6*OCT, 1
        SNOTE   1, 14, NT_CS+6*OCT, 0
        SNOTE   2, 14, NT_E+6*OCT,  0
        SNOTE   0, 12, NT_A+3*OCT,  1
        SNOTE   0,  9, NT_A+3*OCT,  1
        SNOTE   1, 11, NT_D+6*OCT,  0
        SNOTE   0,  9, NT_G+3*OCT,  0
        SNOTE   2,  9, NT_FS+6*OCT, 1
        SNOTE   2,  9, NT_A+6*OCT,  0
        SNOTE   0,  9, NT_D+4*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   1,  6, NT_B+5*OCT,  1
        SNOTE   1,  9, NT_A+5*OCT,  0
        SNOTE   2,  9, NT_FS+6*OCT, 0
        SNOTE   0,  9, NT_G+4*OCT,  1
        SNOTE   2, 17, NT_E+6*OCT,  0
        SNOTE   1, 12, NT_B+5*OCT,  0
        SNOTE   0,  9, NT_B+3*OCT,  1
        SNOTE   0,  9, NT_FS+4*OCT, 1
        SNOTE   0,  9, NT_B+4*OCT,  1
        SNOTE   1, 12, NT_A+5*OCT,  0
        SNOTE   0,  9, NT_B+3*OCT,  1
        SNOTE   0,  9, NT_FS+4*OCT, 1
        SNOTE   0,  9, NT_B+4*OCT,  1
        SNOTE   2, 17, NT_DS+6*OCT, 0
        SNOTE   1, 12, NT_G+5*OCT,  0
        SNOTE   0,  9, NT_B+3*OCT,  1
        SNOTE   0,  9, NT_FS+4*OCT, 1
        SNOTE   0,  9, NT_B+4*OCT,  1
        SNOTE   1, 12, NT_FS+5*OCT, 0
        SNOTE   0,  9, NT_B+3*OCT,  1
        SNOTE   0,  9, NT_FS+4*OCT, 1
        SNOTE   0,  9, NT_B+4*OCT,  1
tuneA17_v0:
        SCALL   setupA
        SNOTE   2, 11, NT_B+5*OCT,  0
        SNOTE   0, 11, NT_E+3*OCT,  0
        SNOTE   1, 11, NT_G+5*OCT,  0
        SNOTE   0,  9, REST,        1
        SNOTE   0,  9, NT_B+3*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   2,  6, NT_E+6*OCT,  0
        SNOTE   1,  6, NT_B+5*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  0
        SNOTE   0,  9, NT_E+4*OCT,  0
        SNOTE   1,  9, NT_E+6*OCT,  1
        SNOTE   2,  9, NT_FS+6*OCT, 0
        SNOTE   0,  9, NT_FS+3*OCT, 0
        SNOTE   1,  9, NT_DS+6*OCT, 1
        SNOTE   2,  9, NT_E+6*OCT,  0
        SNOTE   0,  9, NT_B+3*OCT,  0
        SNOTE   1,  9, NT_CS+6*OCT, 1
        SNOTE   2,  9, NT_FS+6*OCT, 0
        SNOTE   0,  9, NT_FS+4*OCT, 0
        SNOTE   1,  9, NT_DS+6*OCT, 1
        SNOTE   2, 11, NT_G+6*OCT,  0
        SNOTE   1, 11, NT_D+6*OCT,  0
        SNOTE   0,  9, NT_G+3*OCT,  0
        SNOTE   0,  9, REST,        1
        SNOTE   0,  9, NT_D+4*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   2,  6, NT_FS+6*OCT, 0
        SNOTE   1,  6, NT_D+6*OCT,  1
        SNOTE   2,  9, NT_E+6*OCT,  0
        SNOTE   0,  9, NT_G+4*OCT,  0
        SNOTE   1,  9, NT_D+6*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  0
        SNOTE   0,  9, NT_A+3*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   2,  9, NT_C+6*OCT,  0
        SNOTE   0,  9, NT_E+4*OCT,  0
        SNOTE   1,  9, NT_A+5*OCT,  1
        SNOTE   2,  9, NT_A+5*OCT,  0
        SNOTE   0,  9, NT_A+4*OCT,  0
        SNOTE   1,  9, NT_FS+5*OCT, 1
        SNOTE   2, 11, NT_B+5*OCT,  0
        SNOTE   1, 11, NT_G+5*OCT,  0
        SNOTE   0,  9, NT_B+3*OCT,  0
        SNOTE   0,  9, REST,        1
        SNOTE   0,  9, NT_B+4*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   2,  6, NT_E+6*OCT,  0
        SNOTE   1,  6, NT_B+5*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  0
        SNOTE   0,  9, NT_B+3*OCT,  0
        SNOTE   1,  9, NT_E+6*OCT,  1
        SNOTE   2,  9, NT_A+6*OCT,  0
        SNOTE   0,  9, NT_C+4*OCT,  0
        SNOTE   1,  9, NT_FS+6*OCT, 1
        SNOTE   2,  9, NT_G+6*OCT,  0
        SNOTE   0,  9, NT_C+5*OCT,  0
        SNOTE   1,  9, NT_E+6*OCT,  1
        SNOTE   2,  9, NT_A+6*OCT,  0
        SNOTE   0,  9, NT_C+4*OCT,  0
        SNOTE   1,  9, NT_FS+6*OCT, 1
        SNOTE   2, 17, NT_B+6*OCT,  0
        SNOTE   1, 14, NT_E+6*OCT,  0
        SNOTE   0, 11, NT_B+3*OCT,  1
        SNOTE   0,  6, NT_B+4*OCT,  1
        SNOTE   0,  9, NT_B+3*OCT,  1
        SNOTE   1, 14, NT_DS+6*OCT, 0
        SNOTE   0, 11, NT_B+3*OCT,  1
        SNOTE   0,  6, NT_B+4*OCT,  1
        SNOTE   0,  9, NT_B+3*OCT,  1
        SNOTE   0, 12, NT_C+4*OCT,  0
        SNOTE   1, 12, NT_E+6*OCT,  0
        SNOTE   2, 11, NT_B+6*OCT,  1
        SNOTE   2,  6, NT_B+6*OCT,  1
        SNOTE   2,  9, NT_B+6*OCT,  1
        SNOTE   0, 12, NT_G+3*OCT,  0
        SNOTE   1, 12, NT_D+6*OCT,  0
        SNOTE   2,  9, NT_B+6*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  1
        SNOTE   2,  9, NT_A+6*OCT,  1
        SNOTE   0, 12, NT_C+4*OCT,  0
        SNOTE   1, 12, NT_E+6*OCT,  0
        SNOTE   2, 11, NT_B+6*OCT,  1
        SNOTE   2,  6, NT_B+6*OCT,  1
        SNOTE   2,  9, NT_B+6*OCT,  1
        SNOTE   0, 12, NT_G+3*OCT,  0
        SNOTE   1, 12, NT_D+6*OCT,  0
        SNOTE   2,  9, NT_B+6*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  1
        SNOTE   2,  9, NT_A+6*OCT,  1
        SNOTE   0, 12, NT_C+4*OCT,  0
        SNOTE   1, 12, NT_E+6*OCT,  0
        SNOTE   2, 11, NT_B+6*OCT,  1
        SNOTE   2,  6, NT_A+6*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  1
        SNOTE   0, 12, NT_C+4*OCT,  0
        SNOTE   1, 12, NT_E+6*OCT,  0
        SNOTE   2,  9, NT_A+6*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  1
        SNOTE   2,  9, NT_E+6*OCT,  1
        SNOTE   0, 17, NT_B+3*OCT,  0
        SNOTE   2, 17, NT_FS+6*OCT, 0
        SNOTE   1,  6, NT_DS+6*OCT, 1
        SNOTE   1,  6, NT_DS+4*OCT, 1
        SNOTE   1,  6, NT_FS+4*OCT, 1
        SNOTE   1,  6, NT_A+4*OCT,  1
        SNOTE   1,  6, NT_B+4*OCT,  1
        SNOTE   1,  6, NT_DS+5*OCT, 1
        SNOTE   1,  6, NT_FS+5*OCT, 1
        SNOTE   1,  6, NT_A+5*OCT,  1
        SNOTE   1,  6, NT_B+5*OCT,  1
        SNOTE   1,  6, NT_DS+6*OCT, 1
        SNOTE   1,  6, NT_FS+6*OCT, 1
        SNOTE   1,  6, NT_A+6*OCT,  1
tuneA18_v0:
        SCALL   setupA
        SNOTE   2, 14, NT_B+6*OCT,  0
        SNOTE   1, 14, NT_G+6*OCT,  0
        SNOTE   0, 11, NT_B+4*OCT,  1
        SNOTE   0,  6, NT_E+5*OCT,  1
        SNOTE   0,  9, NT_G+5*OCT,  1
        SNOTE   2, 14, NT_B+6*OCT,  0
        SNOTE   1, 14, NT_A+6*OCT,  0
        SNOTE   0,  9, NT_FS+5*OCT, 1
        SNOTE   0,  9, NT_E+5*OCT,  1
        SNOTE   0,  9, NT_FS+5*OCT, 1
        SNOTE   2, 14, NT_B+6*OCT,  0
        SNOTE   1, 14, NT_G+6*OCT,  0
        SNOTE   0, 11, NT_G+5*OCT,  1
        SNOTE   0,  6, NT_B+4*OCT,  1
        SNOTE   0,  9, NT_E+5*OCT,  1
        SNOTE   2, 14, NT_C+7*OCT,  0
        SNOTE   1, 14, NT_A+6*OCT,  0
        SNOTE   0,  9, NT_D+5*OCT,  1
        SNOTE   0,  9, NT_C+5*OCT,  1
        SNOTE   0,  9, NT_A+4*OCT,  1
        SNOTE   2, 14, NT_B+6*OCT,  0
        SNOTE   1, 14, NT_G+6*OCT,  0
        SNOTE   0, 11, NT_B+4*OCT,  1
        SNOTE   0,  6, NT_E+5*OCT,  1
        SNOTE   0,  9, NT_G+5*OCT,  1
        SNOTE   2, 14, NT_C+7*OCT,  0
        SNOTE   1, 14, NT_G+6*OCT,  0
        SNOTE   0,  9, NT_A+5*OCT,  1
        SNOTE   0,  9, NT_G+5*OCT,  1
        SNOTE   0,  9, NT_A+5*OCT,  1
        SNOTE   0, 17, NT_B+5*OCT,  0
        SNOTE   1, 14, NT_G+6*OCT,  0
        SNOTE   2, 14, NT_B+6*OCT,  1
        SNOTE   2, 14, NT_B+6*OCT,  0
        SNOTE   1, 14, NT_FS+6*OCT, 1
        SNOTE   0, 12, NT_C+4*OCT,  0
        SNOTE   2, 11, NT_B+6*OCT,  0
        SNOTE   1,  6, NT_E+5*OCT,  1
        SNOTE   1,  6, NT_G+5*OCT,  1
        SNOTE   1,  6, NT_C+6*OCT,  1
        SNOTE   1,  6, NT_E+5*OCT,  0
        SNOTE   2,  6, NT_E+7*OCT,  1
        SNOTE   2,  9, NT_B+6*OCT,  0
        SNOTE   1,  6, NT_G+5*OCT,  1
        SNOTE   1,  6, NT_C+6*OCT,  1
        SNOTE   0, 12, NT_G+3*OCT,  0
        SNOTE   2,  9, NT_D+7*OCT,  0
        SNOTE   1,  6, NT_D+5*OCT,  1
        SNOTE   1,  6, NT_G+5*OCT,  1
        SNOTE   2,  9, NT_B+6*OCT,  0
        SNOTE   1,  6, NT_B+5*OCT,  1
        SNOTE   1,  6, NT_D+5*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  0
        SNOTE   1,  6, NT_G+5*OCT,  1
        SNOTE   1,  6, NT_B+5*OCT,  1
        SNOTE   0, 12, NT_C+4*OCT,  0
        SNOTE   2, 11, NT_E+6*OCT,  0
        SNOTE   1,  6, NT_E+5*OCT,  1
        SNOTE   1,  6, NT_G+5*OCT,  1
        SNOTE   1,  6, NT_C+6*OCT,  1
        SNOTE   1,  6, NT_E+5*OCT,  0
        SNOTE   2,  6, NT_G+6*OCT,  1
        SNOTE   2,  9, NT_C+7*OCT,  0
        SNOTE   1,  6, NT_G+5*OCT,  1
        SNOTE   1,  6, NT_C+6*OCT,  1
        SNOTE   0, 12, NT_G+3*OCT,  0
        SNOTE   2,  9, NT_B+6*OCT,  0
        SNOTE   1,  6, NT_D+5*OCT,  1
        SNOTE   1,  6, NT_G+5*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  0
        SNOTE   1,  6, NT_B+5*OCT,  1
        SNOTE   1,  6, NT_D+5*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  0
        SNOTE   1,  6, NT_G+5*OCT,  1
        SNOTE   1,  6, NT_B+5*OCT,  1
        SNOTE   1, 12, NT_AS+5*OCT, 0
        SNOTE   2, 11, NT_A+6*OCT,  1
        SNOTE   2,  6, NT_D+7*OCT,  1
        SNOTE   2,  9, NT_A+6*OCT,  1
        SNOTE   1, 12, NT_F+5*OCT,  0
        SNOTE   2,  9, NT_C+7*OCT,  1
        SNOTE   2,  9, NT_A+6*OCT,  1
        SNOTE   2,  9, NT_F+6*OCT,  1
        SNOTE   1, 12, NT_AS+5*OCT, 0
        SNOTE   2, 11, NT_D+6*OCT,  1
        SNOTE   2,  6, NT_F+6*OCT,  1
        SNOTE   2,  9, NT_AS+6*OCT, 1
        SNOTE   1, 12, NT_F+5*OCT,  0
        SNOTE   2,  9, NT_A+6*OCT,  1
        SNOTE   2,  9, NT_F+6*OCT,  1
        SNOTE   2,  9, NT_C+6*OCT,  1
tuneA19_v0:
        SCALL   setupA
        SNOTE   0, 14, NT_D+4*OCT,  0
        SNOTE   1, 14, NT_AS+5*OCT, 0
        SNOTE   2, 11, NT_A+6*OCT,  1
        SNOTE   2,  6, NT_F+6*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  1
        SNOTE   2, 17, NT_G+6*OCT,  0
        SNOTE   1, 12, NT_B+5*OCT,  0
        SNOTE   0, 12, NT_D+3*OCT,  1
        SNOTE   0,  9, NT_D+3*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   0, 12, NT_D+3*OCT,  0
        SNOTE   1, 12, NT_B+5*OCT,  1
        SNOTE   0,  9, NT_D+3*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   0, 14, NT_D+4*OCT,  0
        SNOTE   1, 14, NT_AS+5*OCT, 0
        SNOTE   2, 11, NT_A+6*OCT,  1
        SNOTE   2,  6, NT_F+6*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  1
        SNOTE   2, 17, NT_G+6*OCT,  0
        SNOTE   1, 12, NT_B+5*OCT,  0
        SNOTE   0, 12, NT_D+3*OCT,  1
        SNOTE   0,  9, NT_D+3*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   0, 12, NT_D+3*OCT,  0
        SNOTE   1, 12, NT_B+5*OCT,  1
        SNOTE   0,  9, NT_D+3*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   2, 11, NT_A+6*OCT,  0
        SNOTE   1,  9, NT_D+5*OCT,  1
        SNOTE   0, 12, NT_AS+3*OCT, 0
        SNOTE   1,  9, NT_F+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   2,  6, NT_F+6*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  0
        SNOTE   1,  9, NT_AS+5*OCT, 1
        SNOTE   2, 11, NT_AS+6*OCT, 0
        SNOTE   1,  9, NT_D+5*OCT,  1
        SNOTE   0, 12, NT_G+3*OCT,  0
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   2,  6, NT_G+6*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  0
        SNOTE   1,  9, NT_AS+5*OCT, 1
        SNOTE   2, 11, NT_B+6*OCT,  0
        SNOTE   1,  9, NT_D+5*OCT,  1
        SNOTE   0, 12, NT_G+4*OCT,  0
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   2,  6, NT_G+6*OCT,  1
        SNOTE   2,  9, NT_F+6*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   2, 11, NT_C+7*OCT,  0
        SNOTE   1,  9, NT_E+5*OCT,  1
        SNOTE   0, 12, NT_C+4*OCT,  0
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   2,  6, NT_G+6*OCT,  1
        SNOTE   2,  9, NT_F+6*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   2, 11, NT_CS+7*OCT, 0
        SNOTE   1,  9, NT_E+5*OCT,  1
        SNOTE   0, 12, NT_A+3*OCT,  0
        SNOTE   1,  9, NT_A+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   2,  6, NT_A+6*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  0
        SNOTE   1,  9, NT_CS+6*OCT, 1
        SNOTE   2, 11, NT_D+7*OCT,  0
        SNOTE   1,  9, NT_F+5*OCT,  1
        SNOTE   0, 12, NT_D+4*OCT,  0
        SNOTE   1,  9, NT_A+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   2,  6, NT_A+6*OCT,  1
        SNOTE   2,  9, NT_F+6*OCT,  0
        SNOTE   1,  9, NT_D+6*OCT,  1
        SNOTE   2,  9, NT_E+7*OCT,  0
        SNOTE   0,  9, NT_C+4*OCT,  0
        SNOTE   1,  9, NT_A+6*OCT,  1
        SNOTE   0, 11, NT_AS+3*OCT, 0
        SNOTE   1,  9, NT_G+6*OCT,  0
        SNOTE   2,  9, NT_F+7*OCT,  1
        SNOTE   2,  9, NT_G+7*OCT,  0
        SNOTE   1,  9, NT_D+6*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_AS+4*OCT, 1
        SNOTE   2,  9, NT_GS+7*OCT, 0
        SNOTE   0,  9, NT_AS+3*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   0, 14, NT_A+3*OCT,  0
        SNOTE   1, 11, NT_CS+6*OCT, 0
        SNOTE   2, 11, NT_A+7*OCT,  1
        SNOTE   2,  6, NT_A+6*OCT,  0
        SNOTE   1,  6, NT_CS+6*OCT, 1
        SNOTE   2,  9, NT_A+6*OCT,  0
        SNOTE   1,  9, NT_CS+6*OCT, 1
        SNOTE   0, 14, NT_AS+3*OCT, 0
        SNOTE   1, 11, NT_D+6*OCT,  0
        SNOTE   2, 11, NT_A+7*OCT,  1
        SNOTE   2,  6, NT_A+6*OCT,  0
        SNOTE   1,  6, NT_D+6*OCT,  1
        SNOTE   2,  9, NT_A+6*OCT,  0
        SNOTE   1,  9, NT_D+6*OCT,  1
        SNOTE   0, 11, NT_A+3*OCT,  0
        SNOTE   1, 11, NT_CS+6*OCT, 0
        SNOTE   2, 11, NT_A+7*OCT,  1
        SNOTE   2,  6, NT_A+6*OCT,  0
        SNOTE   0,  6, NT_B+3*OCT,  0
        SNOTE   1,  6, NT_CS+6*OCT, 1
        SNOTE   2,  9, NT_A+6*OCT,  0
        SNOTE   1,  9, NT_CS+6*OCT, 0
        SNOTE   0,  9, NT_CS+4*OCT, 1
        SNOTE   2,  9, NT_D+7*OCT,  0
        SNOTE   1,  9, NT_F+6*OCT,  0
        SNOTE   0,  9, NT_D+4*OCT,  1
        SNOTE   0, 11, NT_AS+3*OCT, 0
        SNOTE   1,  9, NT_E+6*OCT,  0
        SNOTE   2,  9, NT_E+7*OCT,  1
        SNOTE   1,  9, NT_D+6*OCT,  0
        SNOTE   2,  9, NT_F+7*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_AS+4*OCT, 1
        SNOTE   0,  9, NT_AS+3*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_G+7*OCT,  1
        SNOTE   0, 14, NT_A+3*OCT,  0
        SNOTE   1, 11, NT_CS+6*OCT, 0
        SNOTE   2, 11, NT_A+7*OCT,  1
        SNOTE   2,  6, NT_A+6*OCT,  0
        SNOTE   1,  6, NT_CS+6*OCT, 1
        SNOTE   2,  9, NT_A+6*OCT,  0
        SNOTE   1,  9, NT_CS+6*OCT, 1
        SNOTE   0, 14, NT_AS+3*OCT, 0
        SNOTE   1, 11, NT_D+6*OCT,  0
        SNOTE   2, 11, NT_A+7*OCT,  1
        SNOTE   2,  6, NT_A+6*OCT,  0
        SNOTE   1,  6, NT_D+6*OCT,  1
        SNOTE   2,  9, NT_A+6*OCT,  0
        SNOTE   1,  9, NT_D+6*OCT,  1
        SNOTE   2, 11, NT_A+7*OCT,  0
        SNOTE   0, 11, NT_A+3*OCT,  0
        SNOTE   1, 11, NT_CS+6*OCT, 1
        SNOTE   2,  6, NT_A+6*OCT,  0
        SNOTE   0,  6, NT_B+3*OCT,  0
        SNOTE   1,  6, NT_CS+6*OCT, 1
        SNOTE   2,  9, NT_A+6*OCT,  0
        SNOTE   1,  9, NT_CS+6*OCT, 0
        SNOTE   0,  9, NT_CS+4*OCT, 1
        SNOTE   0,  9, NT_D+4*OCT,  0
        SNOTE   2,  9, NT_D+7*OCT,  0
        SNOTE   1,  9, NT_F+6*OCT,  1
        SWAIT   0
; Initialize the speaker voices, transpose down two octaves,
; and assign envelopes and LFO waveforms.
setupA:
        SCLEAR  1
        SSET    vfTranspose,     0FFE8h
        SSET    vfEnvBase,       setupA_env_v1
        SSET    vfLfoTable,      lfoSine
        SSET    vfLfoWrap,       1000h
        SSET    vfLfoDepth,      28h
        SSET    vfLfoRate,       12Ch
        SCLEAR  2
        SSET    vfTranspose,     0FFE8h
        SSET    vfReleaseLead,   5
        SSET    vfEnvBase,       setupA_env_v2
        SSET    vfLfoTable,      lfoSine
        SSET    vfLfoWrap,       1000h
        SSET    vfLfoDepth,      14h
        SSET    vfLfoRate,       78h
        SCLEAR  0
        SSET    vfTranspose,     0FFE8h
        SSET    vfEnvBase,       setupA_env_v0
        SSET    vfLfoTable,      lfoZero
        SSET    vfLfoWrap,       200h
        SSET    vfLfoDepth,      78h
        SSET    vfLfoRate,       80h
        SSET    vfTempo,         6
        SRET
; setupA's three envelope lists, one per voice: (value, ticks) pairs walked by
; voice_step, and vfGateLen expiring restarts a voice at the 5th pair.
setupA_env_v2:
        SENV    3,               ENV_SETLEVEL
        SENV    0,               0
        SENV    0,               0
        SENV    0,               0
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0
setupA_env_v1:
        SENV    3,               ENV_SETLEVEL
        SENV    0,               16
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0
setupA_env_v0:
        SENV    3,               ENV_SETLEVEL
        SENV    0,               8
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0
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
        SLOOP   vfLoopCounterA,  tuneB07_v0_loop
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
        SLOOP   vfLoopCounterA,  tuneB05_v0_loop
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
        SLOOP   vfLoopCounterA,  tuneB04_v0_loop
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
; Empty stream: silence the voice and stop.
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
        SLOOP   vfLoopCounterA,  tuneB01_v0_loop
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
        SLOOP   vfLoopCounterA,  tuneB01_v1_loop
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
        SLOOP   vfLoopCounterA,  tuneB01_v2_loop
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
tuneB12_v0:
        SCALL   setupB
        SNOTE   2, 12, NT_C+6*OCT,  1
        SNOTE   2,  9, NT_DS+6*OCT, 1
        SNOTE   2, 17, NT_G+6*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   1,  6, NT_DS+5*OCT, 0
        SNOTE   0,  6, NT_C+4*OCT,  1
        SNOTE   1,  6, NT_DS+5*OCT, 0
        SNOTE   0,  6, NT_C+4*OCT,  1
        SNOTE   1, 17, NT_DS+5*OCT, 0
        SNOTE   0, 17, NT_C+4*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   2,  9, NT_G+6*OCT,  1
        SNOTE   2,  9, NT_F+6*OCT,  1
        SNOTE   2,  9, NT_DS+6*OCT, 1
        SNOTE   2, 12, NT_F+6*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  1
        SNOTE   2, 17, NT_AS+6*OCT, 0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   1,  6, NT_D+5*OCT,  0
        SNOTE   0,  6, NT_AS+3*OCT, 1
        SNOTE   1,  6, NT_D+5*OCT,  0
        SNOTE   0,  6, NT_AS+3*OCT, 1
        SNOTE   0, 15, NT_AS+3*OCT, 0
        SNOTE   1, 15, NT_D+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   2,  9, NT_D+7*OCT,  1
        SNOTE   2,  9, NT_C+7*OCT,  1
        SNOTE   2,  9, NT_AS+6*OCT, 0
        SNOTE   1,  6, NT_F+5*OCT,  0
        SNOTE   0,  6, NT_AS+3*OCT, 1
        SNOTE   1,  6, NT_F+5*OCT,  0
        SNOTE   0,  6, NT_AS+3*OCT, 1
        SNOTE   0, 12, NT_A+3*OCT,  0
        SNOTE   1, 12, NT_F+5*OCT,  0
        SNOTE   2,  9, NT_C+7*OCT,  1
        SNOTE   2,  9, NT_A+6*OCT,  1
        SNOTE   2,  9, NT_F+6*OCT,  0
        SNOTE   1,  6, NT_F+5*OCT,  0
        SNOTE   0,  6, NT_A+4*OCT,  1
        SNOTE   1,  6, NT_F+5*OCT,  0
        SNOTE   0,  6, NT_A+4*OCT,  1
        SNOTE   2, 17, NT_G+6*OCT,  0
        SNOTE   1, 12, NT_D+5*OCT,  0
        SNOTE   0, 12, NT_G+4*OCT,  1
        SNOTE   1,  6, NT_G+5*OCT,  0
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   1,  6, NT_G+5*OCT,  0
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0, 14, NT_G+4*OCT,  0
        SNOTE   1, 14, NT_D+5*OCT,  1
        SNOTE   2, 12, NT_GS+6*OCT, 1
        SNOTE   2,  9, NT_C+7*OCT,  1
        SNOTE   2, 17, NT_DS+7*OCT, 0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_GS+4*OCT, 0
        SNOTE   1,  6, NT_C+5*OCT,  1
        SNOTE   1,  6, NT_C+5*OCT,  0
        SNOTE   0,  6, NT_GS+4*OCT, 1
        SNOTE   0, 15, NT_GS+4*OCT, 0
        SNOTE   1, 15, NT_C+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   2,  9, NT_F+7*OCT,  1
        SNOTE   2,  9, NT_DS+7*OCT, 1
        SNOTE   2,  9, NT_CS+7*OCT, 0
        SNOTE   1,  6, NT_F+5*OCT,  0
        SNOTE   0,  6, NT_CS+4*OCT, 1
        SNOTE   1,  6, NT_F+5*OCT,  0
        SNOTE   0,  6, NT_CS+4*OCT, 1
        SNOTE   2, 12, NT_DS+7*OCT, 0
        SNOTE   0, 12, NT_CS+4*OCT, 0
        SNOTE   1, 12, NT_F+5*OCT,  1
        SNOTE   2,  9, NT_C+7*OCT,  0
        SNOTE   0,  6, NT_GS+4*OCT, 0
        SNOTE   1,  6, NT_C+5*OCT,  1
        SNOTE   1,  6, NT_C+5*OCT,  0
        SNOTE   0,  6, NT_GS+4*OCT, 1
        SNOTE   2, 17, NT_GS+6*OCT, 0
        SNOTE   1, 12, NT_C+5*OCT,  0
        SNOTE   0, 12, NT_GS+4*OCT, 1
        SNOTE   0,  6, NT_GS+4*OCT, 0
        SNOTE   1,  6, NT_C+5*OCT,  1
        SNOTE   1,  6, NT_C+5*OCT,  0
        SNOTE   0,  6, NT_GS+4*OCT, 1
        SNOTE   1, 15, NT_C+5*OCT,  0
        SNOTE   0, 15, NT_GS+4*OCT, 0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, REST,        1
        SNOTE   2,  9, NT_F+7*OCT,  1
        SNOTE   2,  9, NT_DS+7*OCT, 1
        SNOTE   2,  9, NT_CS+7*OCT, 0
        SNOTE   1,  6, NT_F+5*OCT,  0
        SNOTE   0,  6, NT_CS+4*OCT, 1
        SNOTE   1,  6, NT_F+5*OCT,  0
        SNOTE   0,  6, NT_CS+4*OCT, 1
        SNOTE   1, 12, NT_DS+5*OCT, 0
        SNOTE   0, 12, NT_GS+4*OCT, 0
        SNOTE   2,  9, NT_DS+7*OCT, 1
        SNOTE   2,  9, NT_C+7*OCT,  1
        SNOTE   2,  9, NT_GS+6*OCT, 0
        SNOTE   0,  6, NT_GS+4*OCT, 0
        SNOTE   1,  6, NT_DS+5*OCT, 1
        SNOTE   1,  6, NT_DS+5*OCT, 0
        SNOTE   0,  6, NT_GS+4*OCT, 1
        SNOTE   1, 12, NT_F+5*OCT,  0
        SNOTE   0, 12, NT_CS+4*OCT, 0
        SNOTE   2,  9, NT_F+7*OCT,  1
        SNOTE   2,  9, NT_DS+7*OCT, 1
        SNOTE   2,  9, NT_CS+7*OCT, 0
        SNOTE   0,  6, NT_CS+4*OCT, 0
        SNOTE   1,  6, NT_F+5*OCT,  1
        SNOTE   1,  6, NT_F+5*OCT,  0
        SNOTE   0,  6, NT_CS+4*OCT, 1
        SNOTE   1, 12, NT_DS+5*OCT, 0
        SNOTE   0, 12, NT_GS+4*OCT, 0
        SNOTE   2,  9, NT_DS+7*OCT, 1
        SNOTE   2,  9, NT_C+7*OCT,  1
        SNOTE   2,  9, NT_GS+6*OCT, 1
        SNOTE   2, 17, NT_G+6*OCT,  0
        SNOTE   0, 12, REST,        1
        SNOTE   0,  6, NT_G+4*OCT,  0
        SNOTE   1,  6, NT_G+5*OCT,  1
        SNOTE   1,  6, NT_G+5*OCT,  0
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0, 14, NT_G+4*OCT,  0
        SNOTE   1, 14, NT_G+5*OCT,  1
        SNOTE   2,  9, NT_D+7*OCT,  1
        SNOTE   2,  9, NT_B+6*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  1
        SNOTE   2, 17, NT_G+6*OCT,  0
        SNOTE   0, 12, REST,        1
        SNOTE   0,  6, NT_G+4*OCT,  0
        SNOTE   1,  6, NT_G+5*OCT,  1
        SNOTE   1,  6, NT_G+5*OCT,  0
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0, 14, NT_G+4*OCT,  0
        SNOTE   1, 14, NT_G+5*OCT,  1
        SNOTE   2, 11, NT_G+6*OCT,  0
        SNOTE   0,  9, REST,        1
        SNOTE   1,  6, NT_DS+5*OCT, 0
        SNOTE   0,  6, NT_C+4*OCT,  1
        SNOTE   2,  6, NT_DS+6*OCT, 0
        SNOTE   1,  6, NT_DS+5*OCT, 0
        SNOTE   0,  6, NT_C+5*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 0
        SNOTE   0,  9, NT_C+4*OCT,  1
        SNOTE   2, 11, NT_G+6*OCT,  0
        SNOTE   0,  9, REST,        1
        SNOTE   1,  6, NT_DS+5*OCT, 0
        SNOTE   0,  6, NT_C+4*OCT,  1
        SNOTE   2,  6, NT_DS+6*OCT, 0
        SNOTE   1,  6, NT_DS+5*OCT, 0
        SNOTE   0,  6, NT_C+5*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 0
        SNOTE   0,  9, NT_C+4*OCT,  1
        SNOTE   2,  9, NT_C+6*OCT,  1
        SNOTE   2,  9, NT_F+6*OCT,  0
        SNOTE   1,  6, NT_C+5*OCT,  0
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  0
        SNOTE   1,  6, NT_C+5*OCT,  1
        SNOTE   2,  9, NT_GS+6*OCT, 0
        SNOTE   0,  9, NT_F+4*OCT,  0
        SNOTE   1,  9, NT_C+5*OCT,  1
        SNOTE   2, 11, NT_G+6*OCT,  0
        SNOTE   0,  9, REST,        1
        SNOTE   1,  6, NT_DS+5*OCT, 0
        SNOTE   0,  6, NT_C+4*OCT,  1
        SNOTE   2,  6, NT_DS+6*OCT, 0
        SNOTE   1,  6, NT_DS+5*OCT, 0
        SNOTE   0,  6, NT_C+5*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 0
        SNOTE   0,  9, NT_C+4*OCT,  1
        SNOTE   2, 11, NT_G+6*OCT,  0
        SNOTE   0,  9, REST,        1
        SNOTE   1,  6, NT_DS+5*OCT, 0
        SNOTE   0,  6, NT_C+4*OCT,  1
        SNOTE   2,  6, NT_DS+6*OCT, 0
        SNOTE   1,  6, NT_DS+5*OCT, 0
        SNOTE   0,  6, NT_C+5*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 0
        SNOTE   0,  9, NT_C+4*OCT,  1
        SNOTE   2,  9, NT_C+7*OCT,  1
        SNOTE   2,  9, NT_F+7*OCT,  0
        SNOTE   1,  6, NT_C+5*OCT,  0
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  0
        SNOTE   1,  6, NT_C+5*OCT,  1
        SNOTE   0,  9, NT_F+4*OCT,  0
        SNOTE   2,  9, NT_GS+7*OCT, 0
        SNOTE   1,  9, NT_C+5*OCT,  1
tuneB13_v0:
        SCALL   setupB
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   0,  6, NT_GS+4*OCT, 1
        SNOTE   0,  6, NT_AS+4*OCT, 1
        SNOTE   0,  6, NT_C+5*OCT,  1
        SNOTE   0,  6, NT_D+5*OCT,  1
        SNOTE   0,  6, NT_DS+5*OCT, 1
        SNOTE   0,  6, NT_F+5*OCT,  1
        SNOTE   0,  6, NT_G+5*OCT,  1
        SNOTE   0,  6, NT_F+5*OCT,  1
        SNOTE   0,  6, NT_G+5*OCT,  1
        SNOTE   0,  6, NT_F+5*OCT,  1
        SNOTE   0,  6, NT_G+5*OCT,  1
        SNOTE   0,  6, NT_F+5*OCT,  1
        SNOTE   0,  6, NT_GS+5*OCT, 1
        SNOTE   0,  6, NT_AS+5*OCT, 1
        SNOTE   0,  6, NT_C+6*OCT,  1
        SNOTE   0,  6, NT_D+6*OCT,  1
        SNOTE   0,  6, NT_DS+6*OCT, 1
        SNOTE   0,  6, NT_F+6*OCT,  1
        SNOTE   2, 17, NT_D+6*OCT,  0
        SNOTE   1, 17, NT_C+6*OCT,  0
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   0,  6, NT_GS+4*OCT, 1
        SNOTE   0,  6, NT_AS+4*OCT, 1
        SNOTE   0,  6, NT_C+5*OCT,  1
        SNOTE   0,  6, NT_D+5*OCT,  1
        SNOTE   0,  6, NT_DS+5*OCT, 1
        SNOTE   0,  6, NT_F+5*OCT,  1
        SNOTE   2, 17, NT_D+6*OCT,  0
        SNOTE   1, 17, NT_B+5*OCT,  0
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   0,  6, NT_GS+4*OCT, 1
        SNOTE   0,  6, NT_AS+4*OCT, 1
        SNOTE   0,  6, NT_C+5*OCT,  1
        SNOTE   0,  6, NT_D+5*OCT,  1
        SNOTE   0,  6, NT_DS+5*OCT, 1
        SNOTE   0,  6, NT_F+5*OCT,  1
        SNOTE   1, 14, NT_C+6*OCT,  0
        SNOTE   2, 11, NT_D+6*OCT,  0
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  0
        SNOTE   2,  6, NT_D+6*OCT,  0
        SNOTE   1,  6, NT_C+6*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   1, 14, NT_C+6*OCT,  0
        SNOTE   2, 11, NT_D+6*OCT,  0
        SNOTE   0,  6, NT_GS+4*OCT, 1
        SNOTE   0,  6, NT_AS+4*OCT, 1
        SNOTE   0,  6, NT_C+5*OCT,  1
        SNOTE   0,  6, NT_D+5*OCT,  0
        SNOTE   2,  6, NT_D+6*OCT,  0
        SNOTE   1,  6, NT_C+6*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   0,  6, NT_DS+5*OCT, 1
        SNOTE   0,  6, NT_F+5*OCT,  1
        SNOTE   2, 11, NT_D+6*OCT,  0
        SNOTE   1, 11, NT_B+5*OCT,  0
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  0
        SNOTE   2,  6, NT_D+6*OCT,  0
        SNOTE   1,  6, NT_B+5*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  0
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   2, 11, NT_D+6*OCT,  0
        SNOTE   1, 11, NT_B+5*OCT,  0
        SNOTE   0,  6, NT_GS+4*OCT, 1
        SNOTE   0,  6, NT_AS+4*OCT, 1
        SNOTE   0,  6, NT_C+5*OCT,  1
        SNOTE   0,  6, NT_D+5*OCT,  0
        SNOTE   2,  6, NT_D+6*OCT,  0
        SNOTE   1,  6, NT_B+5*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  0
        SNOTE   0,  6, NT_DS+5*OCT, 1
        SNOTE   0,  6, NT_F+5*OCT,  1
        SNOTE   2, 11, NT_D+6*OCT,  0
        SNOTE   1, 11, NT_C+6*OCT,  0
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  0
        SNOTE   2,  6, NT_D+6*OCT,  0
        SNOTE   1,  6, NT_C+6*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   2, 11, NT_D+6*OCT,  0
        SNOTE   1, 11, NT_C+6*OCT,  0
        SNOTE   0,  6, NT_GS+4*OCT, 1
        SNOTE   0,  6, NT_AS+4*OCT, 1
        SNOTE   0,  6, NT_C+5*OCT,  1
        SNOTE   0,  6, NT_D+5*OCT,  0
        SNOTE   2,  6, NT_D+6*OCT,  0
        SNOTE   1,  6, NT_C+6*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   0,  6, NT_DS+5*OCT, 1
        SNOTE   0,  6, NT_F+5*OCT,  1
        SNOTE   2, 11, NT_D+6*OCT,  0
        SNOTE   1, 11, NT_B+5*OCT,  0
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  0
        SNOTE   2,  6, NT_D+6*OCT,  0
        SNOTE   1,  6, NT_B+5*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  0
        SNOTE   0,  6, NT_G+4*OCT,  1
        SNOTE   0,  6, NT_F+4*OCT,  1
        SNOTE   2, 11, NT_D+6*OCT,  0
        SNOTE   1, 11, NT_B+5*OCT,  0
        SNOTE   0,  6, NT_GS+4*OCT, 1
        SNOTE   0,  6, NT_AS+4*OCT, 1
        SNOTE   0,  6, NT_C+5*OCT,  1
        SNOTE   0,  6, NT_D+5*OCT,  0
        SNOTE   2,  6, NT_D+6*OCT,  0
        SNOTE   1,  6, NT_B+5*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  0
        SNOTE   0,  6, NT_DS+5*OCT, 1
        SNOTE   0,  6, NT_F+5*OCT,  1
tuneB14_v0:
        SCALL   setupB
        SNOTE   2, 12, NT_C+6*OCT,  0
        SNOTE   0, 11, NT_C+4*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 1
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_C+5*OCT,  1
        SNOTE   0,  9, NT_C+4*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_DS+6*OCT, 1
        SNOTE   2, 17, NT_G+6*OCT,  0
        SNOTE   0, 11, NT_C+4*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 1
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_C+5*OCT,  1
        SNOTE   0,  9, NT_C+4*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   0, 11, NT_C+4*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 1
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_C+5*OCT,  1
        SNOTE   0,  9, NT_C+4*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   0, 11, NT_C+4*OCT,  0
        SNOTE   2,  9, NT_G+6*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 1
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   2,  9, NT_F+6*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_C+5*OCT,  1
        SNOTE   0,  9, NT_C+4*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_DS+6*OCT, 1
        SNOTE   2, 12, NT_F+6*OCT,  0
        SNOTE   0, 11, NT_AS+3*OCT, 0
        SNOTE   1,  9, NT_D+5*OCT,  1
        SNOTE   1,  9, NT_F+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_AS+4*OCT, 1
        SNOTE   0,  9, NT_AS+3*OCT, 0
        SNOTE   1,  9, NT_AS+5*OCT, 0
        SNOTE   2,  9, NT_D+6*OCT,  1
        SNOTE   2, 17, NT_AS+6*OCT, 0
        SNOTE   0, 11, NT_AS+3*OCT, 0
        SNOTE   1,  9, NT_D+5*OCT,  1
        SNOTE   1,  9, NT_F+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_AS+4*OCT, 1
        SNOTE   0,  9, NT_AS+3*OCT, 0
        SNOTE   1,  9, NT_AS+5*OCT, 1
        SNOTE   0, 11, NT_AS+3*OCT, 0
        SNOTE   1,  9, NT_D+5*OCT,  1
        SNOTE   1,  9, NT_F+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_AS+4*OCT, 1
        SNOTE   0,  9, NT_AS+3*OCT, 0
        SNOTE   1,  9, NT_AS+5*OCT, 1
        SNOTE   0, 11, NT_AS+3*OCT, 0
        SNOTE   2,  9, NT_D+7*OCT,  0
        SNOTE   1,  9, NT_D+5*OCT,  1
        SNOTE   1,  9, NT_F+5*OCT,  0
        SNOTE   2,  9, NT_C+7*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_AS+4*OCT, 1
        SNOTE   0,  9, NT_AS+3*OCT, 0
        SNOTE   1,  9, NT_AS+5*OCT, 0
        SNOTE   2,  9, NT_AS+6*OCT, 1
        SNOTE   0, 11, NT_A+3*OCT,  0
        SNOTE   2,  9, NT_C+7*OCT,  0
        SNOTE   1,  9, NT_A+5*OCT,  1
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_A+6*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_A+4*OCT,  1
        SNOTE   0,  9, NT_A+3*OCT,  0
        SNOTE   1,  9, NT_A+5*OCT,  0
        SNOTE   2,  9, NT_F+6*OCT,  1
        SNOTE   2, 17, NT_G+6*OCT,  0
        SNOTE   0, 11, NT_G+4*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   1,  9, NT_DS+6*OCT, 0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_G+5*OCT,  1
        SNOTE   0,  9, NT_G+4*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   0, 11, NT_G+4*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   1,  9, NT_DS+6*OCT, 0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_G+5*OCT,  1
        SNOTE   0,  9, NT_G+4*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   2, 17, NT_G+6*OCT,  0
        SNOTE   0, 11, NT_G+4*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   1,  9, NT_D+6*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_G+5*OCT,  1
        SNOTE   0,  9, NT_G+4*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   0, 11, NT_G+4*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   1,  9, NT_D+6*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_G+5*OCT,  1
        SNOTE   0,  9, NT_G+4*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   2, 12, NT_GS+6*OCT, 0
        SNOTE   0, 11, NT_GS+4*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   1,  9, NT_DS+6*OCT, 0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_GS+5*OCT, 1
        SNOTE   0,  9, NT_GS+4*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_C+7*OCT,  1
        SNOTE   2, 17, NT_DS+7*OCT, 0
        SNOTE   0, 11, NT_GS+4*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   1,  9, NT_DS+6*OCT, 0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_GS+5*OCT, 1
        SNOTE   0,  9, NT_GS+4*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   0, 11, NT_GS+4*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   1,  9, NT_DS+6*OCT, 0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_GS+5*OCT, 1
        SNOTE   0,  9, NT_GS+4*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   0,  9, NT_CS+4*OCT, 0
        SNOTE   1,  9, NT_F+5*OCT,  0
        SNOTE   2,  9, NT_F+7*OCT,  1
        SNOTE   0,  9, NT_F+4*OCT,  0
        SNOTE   1,  9, NT_GS+5*OCT, 0
        SNOTE   2,  9, NT_DS+7*OCT, 1
        SNOTE   0,  9, NT_GS+4*OCT, 0
        SNOTE   1,  9, NT_CS+6*OCT, 0
        SNOTE   2,  9, NT_CS+7*OCT, 1
        SNOTE   2, 12, NT_DS+7*OCT, 0
        SNOTE   0, 11, NT_GS+4*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   1,  9, NT_DS+6*OCT, 0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_GS+5*OCT, 1
        SNOTE   0,  9, NT_GS+4*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_C+7*OCT,  1
        SNOTE   2, 17, NT_GS+6*OCT, 0
        SNOTE   0, 11, NT_GS+4*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   1,  9, NT_DS+6*OCT, 0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_GS+5*OCT, 1
        SNOTE   0,  9, NT_GS+4*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   0, 11, NT_GS+4*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   1,  9, NT_DS+6*OCT, 0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_GS+5*OCT, 1
        SNOTE   0,  9, NT_GS+4*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   0,  9, NT_CS+4*OCT, 0
        SNOTE   1,  9, NT_F+5*OCT,  0
        SNOTE   2,  9, NT_F+7*OCT,  1
        SNOTE   0,  9, NT_F+4*OCT,  0
        SNOTE   1,  9, NT_GS+5*OCT, 0
        SNOTE   2,  9, NT_DS+7*OCT, 1
        SNOTE   0,  9, NT_GS+4*OCT, 0
        SNOTE   1,  9, NT_CS+6*OCT, 0
        SNOTE   2,  9, NT_CS+7*OCT, 1
        SNOTE   0, 11, NT_GS+4*OCT, 0
        SNOTE   2,  9, NT_DS+7*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   1,  9, NT_DS+6*OCT, 0
        SNOTE   2,  9, NT_C+7*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_GS+5*OCT, 1
        SNOTE   0,  9, NT_GS+4*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_GS+6*OCT, 1
        SNOTE   0,  9, NT_CS+4*OCT, 0
        SNOTE   1,  9, NT_F+5*OCT,  0
        SNOTE   2,  9, NT_F+7*OCT,  1
        SNOTE   0,  9, NT_F+4*OCT,  0
        SNOTE   1,  9, NT_GS+5*OCT, 0
        SNOTE   2,  9, NT_DS+7*OCT, 1
        SNOTE   0,  9, NT_GS+4*OCT, 0
        SNOTE   1,  9, NT_CS+6*OCT, 0
        SNOTE   2,  9, NT_CS+7*OCT, 1
        SNOTE   0, 11, NT_G+4*OCT,  0
        SNOTE   2,  9, NT_DS+7*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   1,  9, NT_DS+6*OCT, 0
        SNOTE   2,  9, NT_C+7*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_G+5*OCT,  1
        SNOTE   0,  9, NT_G+4*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_GS+6*OCT, 1
        SNOTE   2, 17, NT_G+6*OCT,  0
        SNOTE   0, 11, NT_G+4*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   1,  9, NT_DS+6*OCT, 0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_G+5*OCT,  1
        SNOTE   0,  9, NT_G+4*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   0, 11, NT_G+4*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   1,  9, NT_DS+6*OCT, 0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_G+5*OCT,  1
        SNOTE   0,  9, NT_G+4*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   0, 11, NT_G+4*OCT,  0
        SNOTE   2,  9, NT_D+7*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   1,  9, NT_D+6*OCT,  0
        SNOTE   2,  9, NT_B+6*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_G+5*OCT,  1
        SNOTE   0,  9, NT_G+4*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  0
        SNOTE   2,  9, NT_G+6*OCT,  1
        SNOTE   2, 17, NT_G+6*OCT,  0
        SNOTE   0, 11, NT_G+4*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   1,  9, NT_D+6*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_G+5*OCT,  1
        SNOTE   0,  9, NT_G+4*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   0, 11, NT_G+4*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   1,  9, NT_D+6*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_G+5*OCT,  1
        SNOTE   0,  9, NT_G+4*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
tuneB15_v0:
        SCALL   setupB
        SNOTE   0, 11, NT_C+4*OCT,  0
        SNOTE   2, 11, NT_G+6*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 1
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_C+5*OCT,  0
        SNOTE   2,  6, NT_DS+6*OCT, 1
        SNOTE   0,  9, NT_C+4*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_G+6*OCT,  1
        SNOTE   0, 11, NT_C+4*OCT,  0
        SNOTE   2, 11, NT_G+6*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 1
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_C+5*OCT,  0
        SNOTE   2,  6, NT_DS+6*OCT, 1
        SNOTE   0,  9, NT_C+4*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_G+6*OCT,  1
        SNOTE   0,  9, NT_F+4*OCT,  0
        SNOTE   1,  9, NT_GS+5*OCT, 0
        SNOTE   2,  9, NT_C+6*OCT,  1
        SNOTE   0,  9, NT_GS+4*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_F+6*OCT,  1
        SNOTE   0,  9, NT_C+5*OCT,  0
        SNOTE   1,  9, NT_F+6*OCT,  0
        SNOTE   2,  9, NT_GS+6*OCT, 1
        SNOTE   0, 11, NT_C+4*OCT,  0
        SNOTE   2, 11, NT_G+6*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 1
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_C+5*OCT,  0
        SNOTE   2,  6, NT_DS+6*OCT, 1
        SNOTE   0,  9, NT_C+4*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_G+6*OCT,  1
        SNOTE   0, 11, NT_C+4*OCT,  0
        SNOTE   2, 11, NT_G+6*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 1
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_C+5*OCT,  0
        SNOTE   2,  6, NT_DS+6*OCT, 1
        SNOTE   0,  9, NT_C+4*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_G+6*OCT,  1
        SNOTE   0,  9, NT_F+4*OCT,  0
        SNOTE   1,  9, NT_GS+5*OCT, 0
        SNOTE   2,  9, NT_C+7*OCT,  1
        SNOTE   0,  9, NT_GS+4*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_F+7*OCT,  1
        SNOTE   0,  9, NT_C+5*OCT,  0
        SNOTE   1,  9, NT_F+6*OCT,  0
        SNOTE   2,  9, NT_GS+7*OCT, 1
        SNOTE   0, 11, NT_C+4*OCT,  0
        SNOTE   2, 11, NT_G+6*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 1
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_C+5*OCT,  0
        SNOTE   2,  6, NT_DS+6*OCT, 1
        SNOTE   0,  9, NT_C+4*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_G+6*OCT,  1
        SNOTE   0, 11, NT_C+4*OCT,  0
        SNOTE   2, 11, NT_G+6*OCT,  0
        SNOTE   1,  9, NT_DS+5*OCT, 1
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_C+5*OCT,  0
        SNOTE   2,  6, NT_DS+6*OCT, 1
        SNOTE   0,  9, NT_C+4*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_G+6*OCT,  1
        SNOTE   0,  9, NT_F+4*OCT,  0
        SNOTE   1,  9, NT_A+5*OCT,  0
        SNOTE   2,  9, NT_C+7*OCT,  1
        SNOTE   0,  9, NT_A+4*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_F+7*OCT,  1
        SNOTE   0,  9, NT_C+5*OCT,  0
        SNOTE   1,  9, NT_F+6*OCT,  0
        SNOTE   2,  9, NT_GS+7*OCT, 1
        SNOTE   1, 17, NT_C+6*OCT,  0
        SNOTE   2, 17, NT_GS+7*OCT, 0
        SNOTE   0, 12, NT_GS+4*OCT, 1
        SNOTE   0,  9, NT_GS+4*OCT, 1
        SNOTE   0, 12, NT_GS+4*OCT, 1
        SNOTE   0,  9, NT_GS+4*OCT, 1
        SNOTE   0, 12, NT_GS+4*OCT, 1
tuneB16_v0:
        SCALL   setupB
        SNOTE   0,  9, NT_GS+4*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_DS+6*OCT, 1
        SNOTE   0, 12, NT_GS+4*OCT, 0
        SNOTE   2, 11, NT_E+6*OCT,  0
        SNOTE   1, 11, NT_CS+6*OCT, 1
        SNOTE   2,  6, NT_FS+6*OCT, 1
        SNOTE   0,  9, NT_GS+4*OCT, 0
        SNOTE   1,  9, NT_CS+6*OCT, 0
        SNOTE   2,  9, NT_GS+6*OCT, 1
        SNOTE   1, 15, NT_C+6*OCT,  0
        SNOTE   2, 15, NT_DS+6*OCT, 0
        SNOTE   0, 12, NT_GS+4*OCT, 1
        SNOTE   0,  9, NT_GS+4*OCT, 1
        SNOTE   0, 12, NT_GS+4*OCT, 1
        SNOTE   0,  9, NT_GS+4*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_DS+6*OCT, 1
        SNOTE   0, 12, NT_GS+4*OCT, 0
        SNOTE   2, 11, NT_E+6*OCT,  0
        SNOTE   1, 11, NT_CS+6*OCT, 1
        SNOTE   2,  6, NT_FS+6*OCT, 1
        SNOTE   0,  9, NT_GS+4*OCT, 0
        SNOTE   1,  9, NT_CS+6*OCT, 0
        SNOTE   2,  9, NT_GS+6*OCT, 1
        SNOTE   1, 14, NT_DS+6*OCT, 0
        SNOTE   0, 11, NT_B+3*OCT,  0
        SNOTE   2,  9, NT_FS+6*OCT, 1
        SNOTE   2,  9, NT_B+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_CS+4*OCT, 1
        SNOTE   2,  9, NT_B+6*OCT,  0
        SNOTE   0,  9, NT_DS+4*OCT, 1
        SNOTE   0, 14, NT_E+4*OCT,  0
        SNOTE   1, 14, NT_B+5*OCT,  0
        SNOTE   2, 11, NT_GS+6*OCT, 1
        SNOTE   2,  6, NT_FS+6*OCT, 1
        SNOTE   2,  9, NT_E+6*OCT,  1
        SNOTE   0, 14, NT_C+4*OCT,  0
        SNOTE   2,  9, NT_G+6*OCT,  0
        SNOTE   1,  9, NT_E+6*OCT,  1
        SNOTE   1,  9, NT_D+6*OCT,  0
        SNOTE   2,  9, NT_FS+6*OCT, 1
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_E+6*OCT,  1
        SNOTE   0, 14, NT_B+3*OCT,  0
        SNOTE   2,  9, NT_D+6*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   2,  9, NT_B+5*OCT,  1
        SNOTE   1,  9, NT_D+5*OCT,  0
        SNOTE   2,  9, NT_G+5*OCT,  1
        SNOTE   1, 15, NT_CS+6*OCT, 0
        SNOTE   2, 15, NT_E+6*OCT,  0
        SNOTE   0, 12, NT_A+3*OCT,  1
        SNOTE   0,  9, NT_A+3*OCT,  1
        SNOTE   0, 12, NT_A+3*OCT,  1
        SNOTE   0,  9, NT_A+3*OCT,  0
        SNOTE   1,  9, NT_CS+6*OCT, 0
        SNOTE   2,  9, NT_E+6*OCT,  1
        SNOTE   0, 12, NT_A+3*OCT,  0
        SNOTE   2, 11, NT_F+6*OCT,  0
        SNOTE   1, 11, NT_D+6*OCT,  1
        SNOTE   2,  6, NT_G+6*OCT,  1
        SNOTE   2,  9, NT_A+6*OCT,  0
        SNOTE   0,  9, NT_A+3*OCT,  1
        SNOTE   1, 15, NT_CS+6*OCT, 0
        SNOTE   2, 15, NT_E+6*OCT,  0
        SNOTE   0, 12, NT_A+3*OCT,  1
        SNOTE   0,  9, NT_A+3*OCT,  1
        SNOTE   0, 12, NT_A+3*OCT,  1
        SNOTE   0,  9, NT_A+3*OCT,  0
        SNOTE   1,  9, NT_CS+6*OCT, 0
        SNOTE   2,  9, NT_E+6*OCT,  1
        SNOTE   1, 11, NT_D+6*OCT,  0
        SNOTE   2, 11, NT_F+6*OCT,  0
        SNOTE   0,  9, NT_D+4*OCT,  1
        SNOTE   0,  9, NT_C+4*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   2,  6, NT_G+6*OCT,  1
        SNOTE   2,  9, NT_A+6*OCT,  0
        SNOTE   0,  9, NT_AS+3*OCT, 1
        SNOTE   2, 15, NT_E+6*OCT,  0
        SNOTE   1, 15, NT_CS+6*OCT, 0
        SNOTE   0, 12, NT_A+3*OCT,  1
        SNOTE   0,  9, NT_A+3*OCT,  1
        SNOTE   0, 12, NT_A+3*OCT,  1
        SNOTE   0,  9, NT_A+3*OCT,  0
        SNOTE   1,  9, NT_CS+6*OCT, 0
        SNOTE   2,  9, NT_E+6*OCT,  1
        SNOTE   0, 14, NT_G+4*OCT,  0
        SNOTE   1, 11, NT_D+6*OCT,  0
        SNOTE   2,  9, NT_FS+6*OCT, 1
        SNOTE   2,  9, NT_A+6*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   1,  6, NT_B+5*OCT,  1
        SNOTE   1,  9, NT_A+5*OCT,  0
        SNOTE   2,  9, NT_FS+6*OCT, 1
        SNOTE   1, 14, NT_CS+6*OCT, 0
        SNOTE   2, 14, NT_E+6*OCT,  0
        SNOTE   0, 12, NT_A+3*OCT,  1
        SNOTE   0,  9, NT_A+3*OCT,  1
        SNOTE   1, 11, NT_D+6*OCT,  0
        SNOTE   0,  9, NT_G+4*OCT,  0
        SNOTE   2,  9, NT_FS+6*OCT, 1
        SNOTE   2,  9, NT_A+6*OCT,  0
        SNOTE   0,  9, NT_D+4*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   1,  6, NT_B+5*OCT,  1
        SNOTE   1,  9, NT_A+5*OCT,  0
        SNOTE   2,  9, NT_FS+6*OCT, 0
        SNOTE   0,  9, NT_G+4*OCT,  1
        SNOTE   2, 17, NT_E+6*OCT,  0
        SNOTE   1, 12, NT_B+5*OCT,  0
        SNOTE   0,  9, NT_B+3*OCT,  1
        SNOTE   0,  9, NT_FS+4*OCT, 1
        SNOTE   0,  9, NT_B+4*OCT,  1
        SNOTE   1, 12, NT_A+5*OCT,  0
        SNOTE   0,  9, NT_B+3*OCT,  1
        SNOTE   0,  9, NT_FS+4*OCT, 1
        SNOTE   0,  9, NT_B+4*OCT,  1
        SNOTE   2, 17, NT_DS+6*OCT, 0
        SNOTE   1, 12, NT_G+5*OCT,  0
        SNOTE   0,  9, NT_B+3*OCT,  1
        SNOTE   0,  9, NT_FS+4*OCT, 1
        SNOTE   0,  9, NT_B+4*OCT,  1
        SNOTE   1, 12, NT_FS+5*OCT, 0
        SNOTE   0,  9, NT_B+3*OCT,  1
        SNOTE   0,  9, NT_FS+4*OCT, 1
        SNOTE   0,  9, NT_B+4*OCT,  1
tuneB17_v0:
        SCALL   setupB
        SNOTE   2, 11, NT_B+5*OCT,  0
        SNOTE   0, 11, NT_E+4*OCT,  0
        SNOTE   1, 11, NT_G+5*OCT,  0
        SNOTE   0,  9, REST,        1
        SNOTE   0,  9, NT_B+4*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   2,  6, NT_E+6*OCT,  0
        SNOTE   1,  6, NT_B+5*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  0
        SNOTE   0,  9, NT_E+5*OCT,  0
        SNOTE   1,  9, NT_E+6*OCT,  1
        SNOTE   2,  9, NT_FS+6*OCT, 0
        SNOTE   0,  9, NT_FS+4*OCT, 0
        SNOTE   1,  9, NT_DS+6*OCT, 1
        SNOTE   2,  9, NT_E+6*OCT,  0
        SNOTE   0,  9, NT_B+4*OCT,  0
        SNOTE   1,  9, NT_CS+6*OCT, 1
        SNOTE   2,  9, NT_FS+6*OCT, 0
        SNOTE   0,  9, NT_FS+5*OCT, 0
        SNOTE   1,  9, NT_DS+6*OCT, 1
        SNOTE   2, 11, NT_G+6*OCT,  0
        SNOTE   1, 11, NT_D+6*OCT,  0
        SNOTE   0,  9, NT_G+4*OCT,  0
        SNOTE   0,  9, REST,        1
        SNOTE   0,  9, NT_D+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   2,  6, NT_FS+6*OCT, 0
        SNOTE   1,  6, NT_D+6*OCT,  1
        SNOTE   2,  9, NT_E+6*OCT,  0
        SNOTE   0,  9, NT_G+5*OCT,  0
        SNOTE   1,  9, NT_D+6*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  0
        SNOTE   0,  9, NT_A+4*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   2,  9, NT_C+6*OCT,  0
        SNOTE   0,  9, NT_E+5*OCT,  0
        SNOTE   1,  9, NT_A+5*OCT,  1
        SNOTE   2,  9, NT_A+5*OCT,  0
        SNOTE   0,  9, NT_A+4*OCT,  0
        SNOTE   1,  9, NT_FS+5*OCT, 1
        SNOTE   2, 11, NT_B+5*OCT,  0
        SNOTE   1, 11, NT_G+5*OCT,  0
        SNOTE   0,  9, NT_B+3*OCT,  0
        SNOTE   0,  9, REST,        1
        SNOTE   0,  9, NT_B+4*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   2,  6, NT_E+6*OCT,  0
        SNOTE   1,  6, NT_B+5*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  0
        SNOTE   0,  9, NT_B+3*OCT,  0
        SNOTE   1,  9, NT_E+6*OCT,  1
        SNOTE   2,  9, NT_A+6*OCT,  0
        SNOTE   0,  9, NT_C+4*OCT,  0
        SNOTE   1,  9, NT_FS+6*OCT, 1
        SNOTE   2,  9, NT_G+6*OCT,  0
        SNOTE   0,  9, NT_C+5*OCT,  0
        SNOTE   1,  9, NT_E+6*OCT,  1
        SNOTE   2,  9, NT_A+6*OCT,  0
        SNOTE   0,  9, NT_C+4*OCT,  0
        SNOTE   1,  9, NT_FS+6*OCT, 1
        SNOTE   2, 17, NT_B+6*OCT,  0
        SNOTE   1, 14, NT_E+6*OCT,  0
        SNOTE   0, 11, NT_B+3*OCT,  1
        SNOTE   0,  6, NT_B+4*OCT,  1
        SNOTE   0,  9, NT_B+3*OCT,  1
        SNOTE   1, 14, NT_DS+6*OCT, 0
        SNOTE   0, 11, NT_B+3*OCT,  1
        SNOTE   0,  6, NT_B+4*OCT,  1
        SNOTE   0,  9, NT_B+3*OCT,  1
        SNOTE   0, 12, NT_C+4*OCT,  0
        SNOTE   1, 12, NT_E+6*OCT,  0
        SNOTE   2, 11, NT_B+6*OCT,  1
        SNOTE   2,  6, NT_B+6*OCT,  1
        SNOTE   2,  9, NT_B+6*OCT,  1
        SNOTE   1, 12, NT_D+6*OCT,  0
        SNOTE   0, 12, NT_G+4*OCT,  0
        SNOTE   2,  9, NT_B+6*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  1
        SNOTE   2,  9, NT_A+6*OCT,  1
        SNOTE   0, 12, NT_C+4*OCT,  0
        SNOTE   1, 12, NT_E+6*OCT,  0
        SNOTE   2, 11, NT_B+6*OCT,  1
        SNOTE   2,  6, NT_B+6*OCT,  1
        SNOTE   2,  9, NT_B+6*OCT,  1
        SNOTE   1, 12, NT_D+6*OCT,  0
        SNOTE   0, 12, NT_G+4*OCT,  0
        SNOTE   2,  9, NT_B+6*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  1
        SNOTE   2,  9, NT_A+6*OCT,  1
        SNOTE   0, 12, NT_C+4*OCT,  0
        SNOTE   1, 12, NT_E+6*OCT,  0
        SNOTE   2, 11, NT_B+6*OCT,  1
        SNOTE   2,  6, NT_A+6*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  1
        SNOTE   0, 12, NT_C+4*OCT,  0
        SNOTE   1, 12, NT_E+6*OCT,  0
        SNOTE   2,  9, NT_A+6*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  1
        SNOTE   2,  9, NT_E+6*OCT,  1
        SNOTE   0, 17, NT_B+3*OCT,  0
        SNOTE   2, 17, NT_FS+6*OCT, 0
        SNOTE   1,  6, NT_DS+6*OCT, 1
        SNOTE   1,  6, NT_DS+4*OCT, 1
        SNOTE   1,  6, NT_FS+4*OCT, 1
        SNOTE   1,  6, NT_A+4*OCT,  1
        SNOTE   1,  6, NT_B+4*OCT,  1
        SNOTE   1,  6, NT_DS+5*OCT, 1
        SNOTE   1,  6, NT_FS+5*OCT, 1
        SNOTE   1,  6, NT_A+5*OCT,  1
        SNOTE   1,  6, NT_B+5*OCT,  1
        SNOTE   1,  6, NT_DS+6*OCT, 1
        SNOTE   1,  6, NT_FS+6*OCT, 1
        SNOTE   1,  6, NT_A+6*OCT,  1
tuneB18_v0:
        SCALL   setupB
        SNOTE   2, 14, NT_B+6*OCT,  0
        SNOTE   1, 14, NT_G+6*OCT,  0
        SNOTE   0, 11, NT_B+4*OCT,  1
        SNOTE   0,  6, NT_E+5*OCT,  1
        SNOTE   0,  9, NT_G+5*OCT,  1
        SNOTE   2, 14, NT_B+6*OCT,  0
        SNOTE   1, 14, NT_A+6*OCT,  0
        SNOTE   0,  9, NT_FS+5*OCT, 1
        SNOTE   0,  9, NT_E+5*OCT,  1
        SNOTE   0,  9, NT_FS+5*OCT, 1
        SNOTE   2, 14, NT_B+6*OCT,  0
        SNOTE   1, 14, NT_G+6*OCT,  0
        SNOTE   0, 11, NT_G+5*OCT,  1
        SNOTE   0,  6, NT_B+4*OCT,  1
        SNOTE   0,  9, NT_E+5*OCT,  1
        SNOTE   2, 14, NT_C+7*OCT,  0
        SNOTE   1, 14, NT_A+6*OCT,  0
        SNOTE   0,  9, NT_D+5*OCT,  1
        SNOTE   0,  9, NT_C+5*OCT,  1
        SNOTE   0,  9, NT_A+4*OCT,  1
        SNOTE   2, 14, NT_B+6*OCT,  0
        SNOTE   1, 14, NT_G+6*OCT,  0
        SNOTE   0, 11, NT_B+4*OCT,  1
        SNOTE   0,  6, NT_E+5*OCT,  1
        SNOTE   0,  9, NT_G+5*OCT,  1
        SNOTE   2, 14, NT_C+7*OCT,  0
        SNOTE   1, 14, NT_G+6*OCT,  0
        SNOTE   0,  9, NT_A+5*OCT,  1
        SNOTE   0,  9, NT_G+5*OCT,  1
        SNOTE   0,  9, NT_A+5*OCT,  1
        SNOTE   0, 17, NT_B+5*OCT,  0
        SNOTE   1, 14, NT_G+6*OCT,  0
        SNOTE   2, 14, NT_B+6*OCT,  1
        SNOTE   2, 14, NT_B+6*OCT,  0
        SNOTE   1, 14, NT_FS+6*OCT, 1
        SNOTE   0, 12, NT_C+4*OCT,  0
        SNOTE   2, 11, NT_B+6*OCT,  0
        SNOTE   1,  6, NT_E+5*OCT,  1
        SNOTE   1,  6, NT_G+5*OCT,  1
        SNOTE   1,  6, NT_C+6*OCT,  1
        SNOTE   1,  6, NT_E+5*OCT,  0
        SNOTE   2,  6, NT_E+7*OCT,  1
        SNOTE   2,  9, NT_B+6*OCT,  0
        SNOTE   1,  6, NT_G+5*OCT,  1
        SNOTE   1,  6, NT_C+6*OCT,  1
        SNOTE   0, 12, NT_G+4*OCT,  0
        SNOTE   2,  9, NT_D+7*OCT,  0
        SNOTE   1,  6, NT_D+5*OCT,  1
        SNOTE   1,  6, NT_G+5*OCT,  1
        SNOTE   2,  9, NT_B+6*OCT,  0
        SNOTE   1,  6, NT_B+5*OCT,  1
        SNOTE   1,  6, NT_D+5*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  0
        SNOTE   1,  6, NT_G+5*OCT,  1
        SNOTE   1,  6, NT_B+5*OCT,  1
        SNOTE   0, 12, NT_C+4*OCT,  0
        SNOTE   2, 11, NT_E+6*OCT,  0
        SNOTE   1,  6, NT_E+5*OCT,  1
        SNOTE   1,  6, NT_G+5*OCT,  1
        SNOTE   1,  6, NT_C+6*OCT,  1
        SNOTE   1,  6, NT_E+5*OCT,  0
        SNOTE   2,  6, NT_G+6*OCT,  1
        SNOTE   2,  9, NT_C+7*OCT,  0
        SNOTE   1,  6, NT_G+5*OCT,  1
        SNOTE   1,  6, NT_C+6*OCT,  1
        SNOTE   0, 12, NT_G+4*OCT,  0
        SNOTE   2,  9, NT_B+6*OCT,  0
        SNOTE   1,  6, NT_D+5*OCT,  1
        SNOTE   1,  6, NT_G+5*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  0
        SNOTE   1,  6, NT_B+5*OCT,  1
        SNOTE   1,  6, NT_D+5*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  0
        SNOTE   1,  6, NT_G+5*OCT,  1
        SNOTE   1,  6, NT_B+5*OCT,  1
        SNOTE   1, 12, NT_AS+5*OCT, 0
        SNOTE   2, 11, NT_A+6*OCT,  1
        SNOTE   2,  6, NT_D+7*OCT,  1
        SNOTE   2,  9, NT_A+6*OCT,  1
        SNOTE   1, 12, NT_F+5*OCT,  0
        SNOTE   2,  9, NT_C+7*OCT,  1
        SNOTE   2,  9, NT_A+6*OCT,  1
        SNOTE   2,  9, NT_F+6*OCT,  1
        SNOTE   1, 12, NT_AS+5*OCT, 0
        SNOTE   2, 11, NT_D+6*OCT,  1
        SNOTE   2,  6, NT_F+6*OCT,  1
        SNOTE   2,  9, NT_AS+6*OCT, 1
        SNOTE   1, 12, NT_F+5*OCT,  0
        SNOTE   2,  9, NT_A+6*OCT,  1
        SNOTE   2,  9, NT_F+6*OCT,  1
        SNOTE   2,  9, NT_C+6*OCT,  1
tuneB19_v0:
        SCALL   setupB
        SNOTE   0, 14, NT_D+5*OCT,  0
        SNOTE   1, 14, NT_AS+5*OCT, 0
        SNOTE   2, 11, NT_A+6*OCT,  1
        SNOTE   2,  6, NT_F+6*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  1
        SNOTE   2, 17, NT_G+6*OCT,  0
        SNOTE   1, 12, NT_B+5*OCT,  0
        SNOTE   0, 12, NT_D+4*OCT,  1
        SNOTE   0,  9, NT_D+4*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   0, 12, NT_D+4*OCT,  0
        SNOTE   1, 12, NT_B+5*OCT,  1
        SNOTE   0,  9, NT_D+4*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   0, 14, NT_D+5*OCT,  0
        SNOTE   1, 14, NT_AS+5*OCT, 0
        SNOTE   2, 11, NT_A+6*OCT,  1
        SNOTE   2,  6, NT_F+6*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  1
        SNOTE   2, 17, NT_G+6*OCT,  0
        SNOTE   1, 12, NT_B+5*OCT,  0
        SNOTE   0, 12, NT_D+4*OCT,  1
        SNOTE   0,  9, NT_D+4*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   0, 12, NT_D+4*OCT,  0
        SNOTE   1, 12, NT_B+5*OCT,  1
        SNOTE   0,  9, NT_D+4*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   2, 11, NT_A+6*OCT,  0
        SNOTE   1,  9, NT_D+5*OCT,  1
        SNOTE   0, 12, NT_AS+3*OCT, 0
        SNOTE   1,  9, NT_F+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   2,  6, NT_F+6*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  0
        SNOTE   1,  9, NT_AS+5*OCT, 1
        SNOTE   2, 11, NT_AS+6*OCT, 0
        SNOTE   1,  9, NT_D+5*OCT,  1
        SNOTE   0, 12, NT_G+4*OCT,  0
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   2,  6, NT_G+6*OCT,  1
        SNOTE   2,  9, NT_D+6*OCT,  0
        SNOTE   1,  9, NT_AS+5*OCT, 1
        SNOTE   2, 11, NT_B+6*OCT,  0
        SNOTE   1,  9, NT_D+5*OCT,  1
        SNOTE   0, 12, NT_G+4*OCT,  0
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   2,  6, NT_G+6*OCT,  1
        SNOTE   2,  9, NT_F+6*OCT,  0
        SNOTE   1,  9, NT_B+5*OCT,  1
        SNOTE   2, 11, NT_C+7*OCT,  0
        SNOTE   1,  9, NT_E+5*OCT,  1
        SNOTE   0, 12, NT_C+4*OCT,  0
        SNOTE   1,  9, NT_G+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   2,  6, NT_G+6*OCT,  1
        SNOTE   2,  9, NT_F+6*OCT,  0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   2, 11, NT_CS+7*OCT, 0
        SNOTE   1,  9, NT_E+5*OCT,  1
        SNOTE   0, 12, NT_A+3*OCT,  0
        SNOTE   1,  9, NT_A+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   2,  6, NT_A+6*OCT,  1
        SNOTE   2,  9, NT_G+6*OCT,  0
        SNOTE   1,  9, NT_CS+6*OCT, 1
        SNOTE   2, 11, NT_D+7*OCT,  0
        SNOTE   1,  9, NT_F+5*OCT,  1
        SNOTE   0, 12, NT_D+4*OCT,  0
        SNOTE   1,  9, NT_A+5*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   2,  6, NT_A+6*OCT,  1
        SNOTE   2,  9, NT_F+6*OCT,  0
        SNOTE   1,  9, NT_D+6*OCT,  1
        SNOTE   2,  9, NT_E+7*OCT,  0
        SNOTE   0,  9, NT_C+4*OCT,  0
        SNOTE   1,  9, NT_A+6*OCT,  1
        SNOTE   0, 11, NT_AS+3*OCT, 0
        SNOTE   1,  9, NT_G+6*OCT,  0
        SNOTE   2,  9, NT_F+7*OCT,  1
        SNOTE   2,  9, NT_G+7*OCT,  0
        SNOTE   1,  9, NT_D+6*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_AS+4*OCT, 1
        SNOTE   2,  9, NT_GS+7*OCT, 0
        SNOTE   0,  9, NT_AS+3*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  1
        SNOTE   0, 14, NT_A+3*OCT,  0
        SNOTE   1, 11, NT_CS+6*OCT, 0
        SNOTE   2, 11, NT_A+7*OCT,  1
        SNOTE   2,  6, NT_A+6*OCT,  0
        SNOTE   1,  6, NT_CS+6*OCT, 1
        SNOTE   2,  9, NT_A+6*OCT,  0
        SNOTE   1,  9, NT_CS+6*OCT, 1
        SNOTE   0, 14, NT_AS+3*OCT, 0
        SNOTE   1, 11, NT_D+6*OCT,  0
        SNOTE   2, 11, NT_A+7*OCT,  1
        SNOTE   2,  6, NT_A+6*OCT,  0
        SNOTE   1,  6, NT_D+6*OCT,  1
        SNOTE   2,  9, NT_A+6*OCT,  0
        SNOTE   1,  9, NT_D+6*OCT,  1
        SNOTE   0, 11, NT_A+3*OCT,  0
        SNOTE   1, 11, NT_CS+6*OCT, 0
        SNOTE   2, 11, NT_A+7*OCT,  1
        SNOTE   2,  6, NT_A+6*OCT,  0
        SNOTE   0,  6, NT_B+3*OCT,  0
        SNOTE   1,  6, NT_CS+6*OCT, 1
        SNOTE   2,  9, NT_A+6*OCT,  0
        SNOTE   1,  9, NT_CS+6*OCT, 0
        SNOTE   0,  9, NT_CS+4*OCT, 1
        SNOTE   2,  9, NT_D+7*OCT,  0
        SNOTE   1,  9, NT_F+6*OCT,  0
        SNOTE   0,  9, NT_D+4*OCT,  1
        SNOTE   0, 11, NT_AS+3*OCT, 0
        SNOTE   1,  9, NT_E+6*OCT,  0
        SNOTE   2,  9, NT_E+7*OCT,  1
        SNOTE   1,  9, NT_D+6*OCT,  0
        SNOTE   2,  9, NT_F+7*OCT,  0
        SNOTE   0,  6, REST,        1
        SNOTE   0,  6, NT_AS+4*OCT, 1
        SNOTE   0,  9, NT_AS+3*OCT, 0
        SNOTE   1,  9, NT_C+6*OCT,  0
        SNOTE   2,  9, NT_G+7*OCT,  1
        SNOTE   0, 14, NT_A+3*OCT,  0
        SNOTE   1, 11, NT_CS+6*OCT, 0
        SNOTE   2, 11, NT_A+7*OCT,  1
        SNOTE   2,  6, NT_A+6*OCT,  0
        SNOTE   1,  6, NT_CS+6*OCT, 1
        SNOTE   2,  9, NT_A+6*OCT,  0
        SNOTE   1,  9, NT_CS+6*OCT, 1
        SNOTE   0, 14, NT_AS+3*OCT, 0
        SNOTE   1, 11, NT_D+6*OCT,  0
        SNOTE   2, 11, NT_A+7*OCT,  1
        SNOTE   2,  6, NT_A+6*OCT,  0
        SNOTE   1,  6, NT_D+6*OCT,  1
        SNOTE   2,  9, NT_A+6*OCT,  0
        SNOTE   1,  9, NT_D+6*OCT,  1
        SNOTE   2, 11, NT_A+7*OCT,  0
        SNOTE   0, 11, NT_A+3*OCT,  0
        SNOTE   1, 11, NT_CS+6*OCT, 1
        SNOTE   2,  6, NT_A+6*OCT,  0
        SNOTE   0,  6, NT_B+3*OCT,  0
        SNOTE   1,  6, NT_CS+6*OCT, 1
        SNOTE   2,  9, NT_A+6*OCT,  0
        SNOTE   1,  9, NT_CS+6*OCT, 0
        SNOTE   0,  9, NT_CS+4*OCT, 1
        SNOTE   0,  9, NT_D+4*OCT,  0
        SNOTE   2,  9, NT_D+7*OCT,  0
        SNOTE   1,  9, NT_F+6*OCT,  1
        SWAIT   0
; Initialize the Tandy voices, transpose down 45 semitones,
; and assign envelopes, release timing and LFO waveforms.
setupB:
        SCLEAR  1
        SSET    vfReleaseLead,   0Ch
        SSET    vfTranspose,     0FFD3h
        SSET    vfEnvBase,       setupB_env_v1
        SSET    vfLfoTable,      lfoSine
        SSET    vfLfoWrap,       1000h
        SSET    vfLfoDepth,      28h
        SSET    vfLfoRate,       12Ch
        SCLEAR  2
        SSET    vfReleaseLead,   7
        SSET    vfTranspose,     0FFD3h
        SSET    vfEnvBase,       setupB_env_v2
        SSET    vfLfoTable,      lfoSine
        SSET    vfLfoWrap,       1000h
        SSET    vfLfoDepth,      16h
        SSET    vfLfoRate,       78h
        SCLEAR  0
        SSET    vfReleaseLead,   7
        SSET    vfTranspose,     0FFD3h
        SSET    vfEnvBase,       setupB_env_v0
        SSET    vfLfoTable,      lfoZero
        SSET    vfLfoWrap,       200h
        SSET    vfLfoDepth,      0C8h
        SSET    vfLfoRate,       10h
        SSET    vfTempo,         6
        SRET
; Tandy voice envelopes.
setupB_env_v2:
        SENV    0C350h,          ENV_SETLEVEL
        SENV    9C4h,            4
        SENV    0F830h,          6
        SENV    0,               0
        SENV    0BB80h,          ENV_SETLEVEL
        SENV    0E0C0h,          6
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0
setupB_env_v1:
        SENV    9C40h,           ENV_SETLEVEL
        SENV    9C4h,            8
        SENV    0F448h,          5
        SENV    0,               0
        SENV    0AFC8h,          ENV_SETLEVEL
        SENV    0F060h,          11
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0
setupB_env_v0:
        SENV    0DEA8h,          ENV_SETLEVEL
        SENV    0FA24h,          6
        SENV    0,               0
        SENV    0,               0
        SENV    0BB80h,          ENV_SETLEVEL
        SENV    0E0C0h,          6
        SENV    0,               ENV_SETLEVEL
        SENV    0,               0

; Saved BIOS timer vector, restored by UninstallSoundTimer.
oldInt8Off      dw      0
oldInt8Seg      dw      0

; ---------------------------------------------------------------------------
; Playback routines.
; ---------------------------------------------------------------------------

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
        mov     al, 0B6h                ; selects ch2, lo/hi byte, mode 3
        out     43h, al
        mov     ax, 13B1h               ; divisor written to ch0 despite ch2 selection above
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
        mov     ax, 0FFFFh              ; write ch0 divisor without a new control word
        out     40h, al
        mov     al, ah
        out     40h, al
        in      al, 61h                 ; drop the speaker gate and the timer gate
        and     al, 0FCh
        out     61h, al
        mov     al, 9Fh                 ; full attenuation on the SN76489's
        out     0C0h, al                ;   three tone voices and its noise voice
        mov     al, 0BFh
        out     0C0h, al
        mov     al, 0DFh
        out     0C0h, al
        mov     al, 0FFh
        out     0C0h, al
        pop     ds
        retf

; seqBusy suppresses reentrant voice work while interrupts are enabled. The local return
; sends EOI; every thirteenth tick chains to the saved handler for timer service.
P_isr:
        sti
        push    ax
        push    bx
        push    dx
        push    ds
        push    si
        mov     ax, CODE
        mov     ds, ax
        cmp     byte ptr cs:[seqBusy], 0
        jnz     isr_div
        mov     byte ptr cs:[seqBusy], 1
        call    tick_spkr
        call    tick_tandy
        mov     byte ptr cs:[seqBusy], 0
isr_div:
        dec     byte ptr cs:[divCount]
        jnz     isr_eoi
        mov     byte ptr cs:[divCount], 13      ; divide timer service by thirteen
        pop     si
        pop     ds
        pop     dx
        pop     bx
        pop     ax
        jmp     dword ptr cs:[oldInt8Off]
isr_eoi:
        mov     al, 20h                 ; EOI to the 8259
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
        mov     bx, cs:[curTune]
        cmp     bx, SilentTune
        jz      spkr_set
        mov     word ptr cs:[spkrVoice], 0
        mov     byte ptr cs:[voiceLeft], 4
        mov     si, offset spkrFreq
        mov     cs:[freqBase], si
        mov     si, offset spkrBlocks
        mov     cs:[voiceBase], si
spkr_loop:
        cmp     [si].vfDuration, 0
        jz      spkr_next
        call    voice_step
        cmp     word ptr cs:[spkrVoice], 0
        jnz     spkr_next
        cmp     [si].vfLevel, 0
        jz      spkr_next
        cmp     [si].vfDuration, 0
        jz      spkr_next
        mov     cs:[spkrVoice], si
spkr_next:
        add     si, SIZE VOICE
        dec     byte ptr cs:[voiceLeft]
        jnz     spkr_loop
        mov     bl, cs:[outputOn]
        cmp     bl, 0
        jz      spkr_set
        mov     bx, cs:[spkrVoice]
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
        mov     bx, cs:[curTune]
        cmp     bx, SilentTune
        jz      tandy_off
        mov     byte ptr cs:[voiceLeft], 4
        mov     si, offset tandyFreq
        mov     cs:[freqBase], si
        mov     si, offset tandyBlocks
        mov     cs:[voiceBase], si
tandy_loop1:
        cmp     [si].vfDuration, 0
        jz      tandy_skip1
        call    voice_step
tandy_skip1:
        add     si, SIZE VOICE
        dec     byte ptr cs:[voiceLeft]
        jnz     tandy_loop1
        mov     al, cs:[outputOn]
        cmp     al, 0
        jz      tandy_off
        mov     byte ptr cs:[voiceLeft], 4
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
        dec     byte ptr cs:[voiceLeft]
        jnz     tandy_loop2
        ret
tandy_off:
        mov     al, 9Fh
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
        jmp     short vs_relloop
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
        mov     cs:[seqVoice], si
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
        jmp     cs:[bx+cmdTable]
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
        jmp     short seq_loop
seq_c_clear:                            ; 0FDh  SCLEAR
        mov     si, [di]
        add     di, 2
        add     si, cs:[voiceBase]
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
        jmp     short seq_loop          ;   and both loop counters survive a reset
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
        mov     si, cs:[seqVoice]
        cmp     [si].vfDuration, 0
        jnz     seq_e_set
        mov     bl, 4                   ; 4 - voiceLeft is this voice's index
        sub     bl, cs:[voiceLeft]
        sub     bh, bh
        mov     byte ptr cs:[bx+voiceTune], 0
        mov     di, 0
seq_e_set:
        mov     [si].vfStream, di
        ret
seq_c_ret:                              ; 0FBh  SRET
        mov     di, cs:[seqRet]
        jmp     seq_loop
seq_c_call:                             ; 0FCh  SCALL
        mov     ax, [di]
        add     di, 2
        mov     cs:[seqRet], di
        mov     di, ax
        jmp     seq_loop

; A note record: voice index and noteLen index in the first byte, then the run-end
; flag and the pitch in the second.  Records run back to back until one carries the
; run-end flag.
seq_note_b:
        mov     bl, [di]
        inc     di
seq_note:
        push    di
        mov     al, bl
        mov     cl, 5
        shr     al, cl
        mul     byte ptr cs:[blockSize]
        add     ax, cs:[voiceBase]
        mov     di, ax                  ; DI = the block of the voice this note is for
        and     bx, 1Fh                 ; the low 5 bits are the noteLen index
        mov     ax, [si].vfTempo
        cmp     al, 0
        jnz     sn_scale
        inc     al                      ; tempo 0 plays as tempo 1
sn_scale:
        mul     byte ptr cs:[bx+noteLen]
        mov     [si].vfDuration, ax
        pop     bx
        push    bx
        mov     al, [bx]                ; the run-end flag and the pitch share this byte
        and     ax, 7Fh
        cmp     ax, REST
        jz      sn_tail
        mov     cx, [si].vfDuration
        mov     [di].vfDuration, cx
        sub     cx, [di].vfReleaseLead
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
        add     bx, cs:[freqBase]
        mov     ax, [bx]
        shr     ax, cl
        mov     [di].vfPeriod, ax
        mov     [di].vfOutPeriod, ax
sn_tail:
        pop     di
        mov     al, [di]
        inc     di
        and     al, 80h
        jnz     sn_more
        jmp     short seq_note_b
sn_more:
        jmp     seq_end

; Load nonzero song pointers and arm those voices for the next tick; zero pointers
; preserve their blocks. seqBusy keeps the ISR out during either voice writer.
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
        mov     cs:[curTune], si
        add     si, si
        add     si, si
        add     si, si                  ; * 8: four words per table row
        mov     byte ptr cs:[seqBusy], 1
        mov     byte ptr cs:[voiceLeft], 4
        mov     di, offset spkrBlocks
vwa_loop:
        mov     ax, cs:[si+songTableA]
        cmp     ax, 0
        jz      vwa_next
        mov     bx, SIZE VOICE - 2
vwa_clr:
        mov     word ptr [bx+di], 0
        sub     bx, 2
        jge     vwa_clr
        mov     [di].vfStream, ax
        mov     bl, 4
        sub     bl, cs:[voiceLeft]
        sub     bh, bh
        mov     ax, cs:[curTune]
        mov     cs:[bx+voiceTune], al
        mov     [di].vfDuration, 1
vwa_next:
        add     di, SIZE VOICE
        add     si, 2
        dec     byte ptr cs:[voiceLeft]
        jnz     vwa_loop
        mov     byte ptr cs:[seqBusy], 0
        pop     ds
        pop     si
        pop     di
        pop     bx
        pop     ax
        pop     bp
        retf

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
        mov     cs:[curTune], si
        add     si, si
        add     si, si
        add     si, si
        mov     byte ptr cs:[seqBusy], 1
        mov     byte ptr cs:[voiceLeft], 4
        mov     di, offset tandyBlocks
vwb_loop:
        mov     ax, cs:[si+songTableB]
        cmp     ax, 0
        jz      vwb_next
        mov     bx, SIZE VOICE - 2
vwb_clr:
        mov     word ptr [bx+di], 0
        sub     bx, 2
        jge     vwb_clr
        mov     [di].vfStream, ax
        mov     bl, 4
        sub     bl, cs:[voiceLeft]
        sub     bh, bh
        mov     ax, cs:[curTune]
        mov     cs:[bx+voiceTune], al
        mov     [di].vfDuration, 1
vwb_next:
        add     di, SIZE VOICE
        add     si, 2
        dec     byte ptr cs:[voiceLeft]
        jnz     vwb_loop
        mov     byte ptr cs:[seqBusy], 0
        pop     ds
        pop     si
        pop     di
        pop     bx
        pop     ax
        pop     bp
        retf

SetSoundOutputEnabled:
        push    bp
        mov     bp, sp
        push    ax
        push    ds
        mov     ax, CODE
        mov     ds, ax
        mov     ax, [bp+6]
        mov     cs:[outputOn], al
        pop     ds
        pop     ax
        pop     bp
        retf

; Unused zero bytes after the last routine.
        db      000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h

CODE    ENDS
        END
