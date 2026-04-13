; This code goes on the dash35b display's ESP chip.
; This is notable different from the mainline dash35 in a few ways:
; 1) The input button system is totally ignored -- all inputs are tied in to the controller instead
; 2) There are no "pages" on this version -- it's radically simplified showing just:
;    - speed, watts, battery voltage, bat %, and motor temp
;    These are what I considered to be the critically important details on the dash

@const-start

; Lib
(import "lib/colors.lisp" 'code-colors)
(read-eval-program code-colors)

(import "lib/draw-utils.lisp" 'code-draw-utils)
(read-eval-program code-draw-utils)

(import "lib/communication.lisp" 'code-communication)
(read-eval-program code-communication)

; View
(import "views/view_static.lbm" 'code-view-static)
(read-eval-program code-view-static)

; Assets
(import "assets/batt_level_50x210.bin" 'img-batt-level)

; Fonts
(import "font/roboto-bold-16-4c.bin" 'font-16)
(import "font/roboto-bold-16-2c.bin" 'font-16-2c)
(import "font/roboto-bold-48-4c.bin" 'font-48)
(import "font/roboto-bold-90-2c.bin" 'font-90)

(defun main () {
    (set-print-prefix "DISP-")

    (if (and
            (> (conf-get 'wifi-mode) 0)
            (> (conf-get 'ble-mode) 0)
        ) {
            (print "WiFi and BLE enabled, not enough memory to run UI. Disabling wifi...")
            (conf-set 'wifi-mode 0)
            (conf-set 'controller-id 4)
            (conf-store)
            (sleep 5)
            (reboot)
        })

    (def dm-pool (dm-create 25600))

    (disp-set-bl 0)
    (disp-reset)
    (disp-orientation 3)
    (disp-clear 0)
    (disp-set-bl 5)

    (event-register-handler (spawn event-handler))
    (event-enable 'event-can-sid)

    (loopwhile-thd ("ViewStatic" 200) t {
        (print "Starting ViewStatic-thread")

        (match (trap (view-static-thread))
            ((exit-ok (? a)) (print "ViewStatic-thread exit"))
            (_ (print "ViewStatic-thread crashed"))
        )

        (sleep 5.0)
    })

})

@const-end

(image-save)
(main)
