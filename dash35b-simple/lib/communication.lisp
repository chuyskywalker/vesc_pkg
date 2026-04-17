
; ID 302
(def stats-drive-mode 5)
(def stats-speed 0)
(def stats-bat-percent 0)
(def stats-motor-temp 0)
(def stats-watts 0)
(def stats-amps 0.0)
(def stats-bat-voltage 0.0)

; See main-stm.lisp for canbus message data

@const-start

(defun proc-sid (id data) {
    (cond
        ((= id 302) {
            (def stats-drive-mode  (bufget-u8 data 0))
            (def stats-speed       (bufget-u8 data 1))
            (def stats-bat-percent (bufget-u8 data 2))
            (def stats-motor-temp  (bufget-u8 data 3))
            (def stats-amps        (/ (bufget-i16 data 4) 10.0))
            (def stats-bat-voltage (/ (bufget-u16 data 6) 100.0))
        })
        )
    (free data)
    ; update the calculated motor watts for display; rounded :D
    (def stats-watts (round (* stats-amps stats-bat-voltage)))
    ; TODO: the battery voltage can get a little flippy; add some smoothing. Maybe for other value as well?
})

(defun event-handler ()
    (loopwhile t
        (recv
            ((event-can-sid . ((? id) . (? data))) (proc-sid id data))
            (_ nil)
)))
