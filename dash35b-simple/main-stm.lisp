; This LISP file is designed to be installed on the STM (maxim) unit in the controller.
; A different file (str365.lisp) is installed on the ESP chip in the controller.
; Finally, installed the normal disp35b package, downloaded it, and injected a bit
; of code to listen for the `301` drive mode and update the drive mode for the display.

; track if the brake light should be on/off
; this will be sent out on canbus so the ESP can turn the light on/off
(def brake-light-val 0)

; Ok, check it out.
; Drive mode 5 is not valid, but when the peripheral ESP kicks on, it'll start
; sending out drive mode messages, when one of those arrives, it WILL NOT
; be "5", so the (proc-sid) below will kick in and set the motor to whatever
; mode the ESP is putting out. Thus the "start up mode" is controlled over in
; the main-esp.lisp file. Cool kids would make this a setting and put it in QML
; etc, etc. I'm not the cool kid today ;D
(def drive-mode 5)

; These MAY flip; I assume that "forward" is whatever the motor starts with and set it as such in (main)
(def m-direction-for-reverse 1)
(def m-direction-for-forward 0)

@const-start

(defun proc-sid (id data) {
    (cond
        ((= id 301) {
            (var drive-mode-new (bufget-u8 data 0))
            (if (!= drive-mode-new drive-mode) {
                ;(print (list "setting drive mode from -> to " drive-mode drive-mode-new))
                (setq drive-mode drive-mode-new)
                (match drive-mode
                    (0 { ; Reverse
                        (conf-set 'l-current-max-scale 0.2)
                        (conf-set 'max-speed (/ 5.0 3.6))
                        (conf-set 'm-invert-direction m-direction-for-reverse)
                    })
                    (1 { ; Neutral
                        (conf-set 'l-current-max-scale 0.0)
                        (conf-set 'max-speed 0)
                        (conf-set 'm-invert-direction m-direction-for-forward)
                    })
                    (2 { ; 1
                        (conf-set 'l-current-max-scale 0.3)
                        (conf-set 'max-speed (/ 12.0 3.6))
                        (conf-set 'm-invert-direction m-direction-for-forward)
                    })
                    (3 { ; 2
                        (conf-set 'l-current-max-scale 0.6)
                        (conf-set 'max-speed (/ 25.0 3.6))
                        (conf-set 'm-invert-direction m-direction-for-forward)
                    })
                    (4 { ; 3
                        (conf-set 'l-current-max-scale 1.0)
                        (conf-set 'max-speed (/ 200.0 3.6))
                        (conf-set 'm-invert-direction m-direction-for-forward)
                    })
                )
            })

        })
    )
})

(defun event-handler () {
    (loopwhile t
        (recv
            ((event-can-sid . ((? id) . (? data))) (proc-sid id data))
            (_ nil)
})))

(defun clamp (value min_val max_val) {
    (cond
        ((< value min_val) min_val)
        ((> value max_val) max_val)
        (t value)
    )
})

(defun main () {
    (set-print-prefix "STM-")

    (print "KNIGHT ACTIVE")

    ; turn on the 12v
    (set-aux 1 1)

    ; reset the forward/reverse based on the startup state where I assume the motor is IN forward mode
    (setq m-direction-for-forward (conf-get 'm-invert-direction))
    (setq m-direction-for-reverse (if (= m-direction-for-forward 0) 1 0))

    ; setup loop for handling incoming can messages
    (event-register-handler (spawn event-handler))
    (event-enable 'event-can-sid)

    ; start a thread to report stats that the display will use

    (var buf-can (array-create 8))
    (loopwhile-thd ("knight dash data" 200) t {

        ; FYI: all of these transfer as ints, thus if you are sending over a float value,
        ;       we multiply by some factor to capture a chunk of the decimal places.
        ;       on the display, these values have to be divded back out.
        ;       I also clamp in a few places where exceptional cases would cause
        ;       a "roll over" value that would report high/low instead
        ;       (technically possible to send floats, but a bit of a waste)
        ; reminder for self:
        ; i8         -128 -     128        u8  0 -      256
        ; i16      -32768 -   32767       u16  0 -    65535
        ; i24    −8388608 - 8388607       u24  0 - 16777215
        (bufclear buf-can)

        ; what's really needed:
        ; drivemode, speed(mph), bat%, watts, bat voltage, motor temp

        ; THIS is the drive mode that the display should show, the one from the
        ; ESP is the intention, but not actual
        (bufset-u8  buf-can 0 drive-mode)

        ; m/s * 2.237ish ~ mph; only 0-256mph, whole numbers, lol
        (bufset-u8  buf-can 1 (* (abs (get-speed)) 2.23694))

        ; 0.0 to 1.0, brought up to 0 - 100; it's percentage, we don't need sub-1% accuracy
        (bufset-u8  buf-can 2 (* (get-batt) 100))

        ; celcius; hot motor would be 150.32C, just lop off the sub 1c accuracy;
        ; under 0C (below freezing outside, bike stored outside) will just get
        ; clamped to zero, but motors heat up so fast it'll resolve quickly
        ; display could simply say "<0" if zero reported
        (bufset-u8  buf-can 3 (clamp (to-i (get-temp-mot)) 0 256))

        ; motor current measured in amps, float32; level up by 100 for accuracy
        ; ie:  25.89 a ->   259
        ;    -489.34 a -> -4893
        ; largest would be 32767/10 = 3276.7 -- likely fine :D
        (bufset-i16 buf-can 4 (clamp (* (get-current) 10) -32768 32767))

        ; voltage leveled up by 100; ie: 76.52v -> 7652
        (bufset-u16 buf-can 6 (* (get-vin) 100))

        (can-send-sid 302 buf-can)

        (sleep 0.1)
    })

    ; main show!
    ; detach the brake control and flip it to regen when pulled
    ; also, when pulled, push out an event that the brake light should be on/off
    (app-adc-detach 2 1)

    (loopwhile-thd ("ADCWatch" 200) t {
        (if (> (get-adc 1) 1.0) {
            (app-adc-override 2 1.0)
            (setq brake-light-val 1)
        }{
            (app-adc-override 2 0.0)
            (setq brake-light-val 0)
        })
        (sleep 0.05)
    })

    ; repeatedly send the brake light state -- if only sent "on change" it's possible
    ; that the ESP could miss the message and now the light isn't in the correct state
    ; until the next message. This repeat ensures state stays accurate.
    ; timer is set low (4 times per second) to reduce noise but still be reasonably quick.
    (loopwhile-thd ("brakelightmsg" 200) t {
        (can-send-sid 314 (list brake-light-val 0 0 0 0 0 0 0))
        (sleep 0.25)
    })

})

@const-end

(image-save)
(main)
