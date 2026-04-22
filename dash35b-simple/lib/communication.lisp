; States to track
(def stats-drive-mode 5)
(def stats-speed 0)
(def stats-bat-percent 0)
(def stats-motor-temp 0)
(def stats-watts 0)
(def stats-motor-amps 0.0)
(def stats-battery-amps 0.0)
(def stats-bat-voltage 0.0)

; See main-stm.lisp for canbus message data

@const-start

(defun proc-sid (id data) {
    (cond
        ((= id 304) {
            (setq stats-drive-mode  (bufget-u8 data 0))
            (setq stats-speed       (/ (bufget-u16 data 1) 10.0))
            (setq stats-bat-percent (bufget-u8 data 3))
            (setq stats-bat-voltage (/ (bufget-u16 data 4) 100.0))
            (setq stats-motor-temp  (/ (bufget-u16 data 6) 100.0))
        })
        ((= id 305) {
            (setq stats-battery-amps  (/ (bufget-i16 data 0) 10.0))
            (setq stats-motor-amps    (/ (bufget-i16 data 2) 10.0))
        })
        )
    (free data)
    ; update the calculated motor watts for display; rounded :D
    (setq stats-watts (to-i (round (* stats-battery-amps stats-bat-voltage))))
})

(defun event-handler ()
    (loopwhile t
        (recv
            ((event-can-sid . ((? id) . (? data))) (proc-sid id data))
            (_ nil)
)))
