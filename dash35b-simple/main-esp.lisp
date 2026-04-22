; This code is designed to be installed on the ESP chip (str365.io) in the maxim controller
; Here we are going to read the buttons and turn on some lights.
; Currently, MOST of the lighting is done directly via switches on the bike; I did not feel like
; wiring up all of the lighting (and the blinking routines) through the VESC.
; This does, however, mean that the display can't mirror the current state of the bike (for instance,
; there is no headlight on/off, no blinkers, etc). I don't really consider it a huge downside, though.
; The system COULD be rewired, but meh for now.

(import "pkg@://vesc_packages/lib_tca9535/tca9535.vescpkg" 'tca9535)
(read-eval-program tca9535)

; The pin numbers here correspond to the IOExpander pin value; harness pin noted in comment
; These should be connected to 12v to be detected as a button push
(def io-pin-park 13) ; pin 24 "neutral input"
(def io-pin-mode 15) ; pin 38 "mode input"

; Tracking last button state so we can detect pushes
(define last-park-state 0)
(define last-mode-state 0)

; Bike startup drive mode
(def drive-mode 4) ; 0 reverse; 1 neutral; 2 low; 3 med; 4 high

; For each button, create a mapping in which, if you query the current mode as
; the index value, you will get the value for the next mode
; Makes for a very efficient and handy remapping when the button is pressed

;                        ix 0   1   2   3   4
;                           R>N N>R L>N M>N H>N
(define park-mappings (list 1   0   1   1   1  ))

;                        ix 0   1   2   3   4
;                           R>L N>L L>M M>H H>L
(define mode-mappings (list 2   2   3   4   2  ))

@const-start

(defun proc-sid (id data) {
    (cond
        ((= id 314) {
            ; Set the brake light on/off if we have a valid bit 'o data
            ; (hilariously, it's actually a whole BYTE when a bit,
            ; could indeed, suffice -- but I'm not gonna arse about trying
            ; to bitwise things here since it's the only data in the
            ; whole packet anyway...)
            (def desired_brake_state (bufget-u8 data 0))
            (cond
                ((= desired_brake_state 0) (gpio-write 3 0))
                ((= desired_brake_state 1) (gpio-write 3 1))
            )
        })
    )
})

(defun event-handler ()
    (loopwhile t
        (recv
            ((event-can-sid . ((? id) . (? data))) (proc-sid id data))
            (_ nil)
)))

; very specific function to as quickly as possible read tca pins, but also not get false positives
(defun read-pins-park-mode () {
    (var park-sum 0)
    (var mode-sum 0)
    (var sample-num 9)
    (looprange j 0 sample-num {
        (sleep 0.001) ; very quick sampling rate + "high" sample count above to denoise the line

        ; a more low-level read of the tca to bypass reading both registers
        (var reg1 (bufcreate 1))
        (i2c-tx-rx (assoc tca9535-regs 'addr) '(1) reg1)

        ; extract the specific pins we want, as they are located in the second register,
        ; we need to subtract 10 from the pin ids to arrive at the correct bit to extract
        (var park-pin (bits-dec-int (bufget-u8 reg1 0) (- io-pin-park 10) 1))
        (var mode-pin (bits-dec-int (bufget-u8 reg1 0) (- io-pin-mode 10) 1))

        ; sum the values
        (setq park-sum (+ park-sum park-pin))
        (setq mode-sum (+ mode-sum mode-pin))
    })
    ; If more than half of the samples are set, report 1, else 0
    (list
        (if (> park-sum (/ sample-num 2)) 1 0)
        (if (> mode-sum (/ sample-num 2)) 1 0))
})

(defun main () {
    (set-print-prefix "ESP-")

    ; https://github.com/vedderb/vesc_pkg/blob/af658dd56a7f9d26c8f38361f42d9eef563d34ce/vl_bike_39p/code_esp.lbm#L174
    ; Force ublox-driver to stop as we will use the same pins for the io-expander
    (uart-start 0 20 21 115200)
    (uart-stop 0)
    ; //end copypaste

    ; just make sure the light is in OUTPUT mode
    (gpio-configure 3 'pin-mode-out)

    (event-register-handler (spawn event-handler))
    (event-enable 'event-can-sid)

    (tca9535-init 0x20 'rate-100k 21 20)
    ; I'm not 100% sure how this works, but with this setup the buttons
    ; get wired 12v & signal to function
    (tca9535-set-dir '(17 out))
    (tca9535-write-pins '(17 0))

    (loopwhile-thd ("readbuttons" 200) t {
        (var pin-states (read-pins-park-mode))
        (var park-state (ix pin-states 0))
        (var mode-state (ix pin-states 1))

        (if (and (= last-park-state 1) (= park-state 0)) {
            (setq drive-mode (ix park-mappings drive-mode))
        })

        (if (and (= last-mode-state 1) (= mode-state 0)) {
            (setq drive-mode (ix mode-mappings drive-mode))
        })

        (setq last-park-state park-state)
        (setq last-mode-state mode-state)

        (sleep 0.010) ; a very quick loop to catch the button presses
    })

    ; send the drive mode on repeat; if we only sent it on button press (in the above thread)
    ; it's possible the message could be missed, but we also dont need to send it SUPER fast
    (loopwhile-thd ("CANSend" 200) t {
        (can-send-sid 301 (list drive-mode 0 0 0 0 0 0 0))
        (sleep 0.100) ; every 100ms, 10 times per second
    })

})

@const-end

(image-save)
(main)
