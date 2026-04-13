
; ID 302
(def stats-drive-mode 5)
(def stats-speed 0)
(def stats-bat-percent 0)
(def stats-motor-temp 0)
(def stats-watts 0)
(def stats-bat-voltage 0.0)

;        ; what's really needed:
;        ; drivemode, speed(mph), bat%, watts, bat voltage, motor temp
;
;        ; THIS is the drive mode that the display should show, the one from the
;        ; ESP is the intention, but not actual
;        (bufset-u8  buf-can 0 drive-mode)
;
;        ; m/s * 2.237ish ~ mph; only 0-256mph, whole numbers, lol
;        (bufset-u8  buf-can 1 (* (abs (get-speed)) 2.23694))
;
;        ; 0.0 to 1.0, brought up to 0 - 100; it's percentage, we don't need sub-1% accuracy
;        (bufset-u8  buf-can 2 (* (get-batt) 100))
;
;        ; celcius; hot motor would be 150.32C, just lop off the sub 1c accuracy;
;        ; under 0C (below freezing outside, bike stored outside) will just get
;        ; clamped to zero, but motors heat up so fast it'll resolve quickly
;        ; display could simply say "<0" if zero reported
;        (bufset-u8  buf-can 3 (clamp (to-i (get-temp-mot)) 0 256))
;
;        ; current measured in amps, float32. multiple by vin (voltage) to get watts, examples:
;        ;  23.3245 *  76.3245 =  1,780.23080025 -> 1780w
;        ; 590.9345 * 145.983  = 86,266.3911135  -> 86266w    << would overflow;
;        ;  -66.540 *  67.239  = -4,474.08306    -> -4474w
;        ; I likely won't see > 32kw, so i'm clamping it into an i16;
;        ; display could see high number and just say "OVER 9000!""
;        (bufset-i16 buf-can 4 (clamp (* (get-current) (get-vin)) -32768 32767)
;
;        ; voltage leveled up by 100; ie: 76.52v -> 7652
;        (bufset-u16 buf-can 6 (* (get-vin) 100))

@const-start

(defun proc-sid (id data) {
    (cond
        ((= id 302) {
            (def stats-drive-mode  (bufget-u8 data 0))
            (def stats-speed       (bufget-u8 data 1))
            (def stats-bat-percent (bufget-u8 data 2))
            (def stats-motor-temp  (bufget-u8 data 3))
            (def stats-watts       (bufget-i16 data 4))
            (def stats-bat-voltage (/ (bufget-i16 data 6) 100.0))
        })
        )
    (free data)
})

(defun event-handler ()
    (loopwhile t
        (recv
            ((event-can-sid . ((? id) . (? data))) (proc-sid id data))
            (_ nil)
)))
