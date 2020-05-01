#lang racket/gui

;; *******************************
;; **** RACKET MIRTO EMULATOR ****
;; *******************************

(provide open-asip
         close-asip
         
         ;playTone

         ;; Myrtle-specific functions
         w1-stopMotor
         w2-stopMotor
         stopMotors
         setMotor
         setMotors
         ;readCount
         ;getCount
         ;resetCount
         ;getIR
         leftBump?
         rightBump?
         ;enableIR
         enableBumpers
         ;enableCounters
         ;setLCDMessage
         ;clearLCD
         ;enableDistance
         ;getDistance
         )


(require math/matrix)
(require 2htdp/image)
(require images/flomap)
(require picturing-programs)

(define gui-thread null)

(define mouse_x 0)
(define mouse_y 0)

(define bumpDelta 18)

;initial position and direction in radiants
(define x 80)
(define y 300)
(define z 0)

;rotation
(define cosz 0)
(define sinz 0)

;variables for power 
(define delta 0)
(define power 0)

(define rightWheelPwr 0)
(define leftWheelPwr 0)

(define bumpersInterval 0) ;0 means disabled
(define right #f)
(define left #f)

(struct point (x y intx inty black)#:mutable)
(struct line (x1 y1 x2 y2)#:mutable)
(struct destination (x y)#:mutable)

;IR sensors
(define ir0 (point 0 0 0 0 #f))
(define ir1 (point 0 0 0 0 #f))
(define ir2 (point 0 0 0 0 #f))

;euclidean test vector
(define direction (destination x y))

;wheels
(define leftWheel (line 0 0 0 0))
(define rightWheel (line 0 0 0 0))


(define bg_img (make-object bitmap% "bg.png"))

(define WIDTH (image-width bg_img))
(define HEIGHT (image-height bg_img))

; Convert image to list of colors
(define list_of_colors (image->color-list bg_img))

; Convert list of colors to list of true/false (true if black, only checking 1 colour)
(define simple_list (map (λ (x) (not (= (color-red x) 255))) list_of_colors))

; utility function that returns the list of positions that are #t (i.e., black)
(define (indexes-of-black l)
  (for/list ((i l)
             (n (in-naturals))
             #:when (equal? i #t))
    n))
; The list of positions that are black. Each number is row*width + column
(define blacks (indexes-of-black simple_list))



(define (position) 
  (set! delta (* 0.0001 (- rightWheelPwr leftWheelPwr)))
  (set! power (* 0.01 (/ ( + leftWheelPwr rightWheelPwr) 2)))
  ;(set! power (* 0.01 (max leftWheel rightWheel)))
  (set! z (+ z delta))
  (set! cosz (cos z))
  (set! sinz (sin z))

  (define tempX (+ x (* cosz power)))
  (define tempY (+ y (* -1 sinz power)))
  
  (cond (
         (and
         ;center of the bot inside the box
         (> tempX bumpDelta) (> tempY bumpDelta) (< tempX (- WIDTH bumpDelta)) (< tempY (- HEIGHT bumpDelta))
         ;internal direction of the bot
         
          )
         (set! x tempX)
         (set! y tempY)
         (set! right #f) (set! left #f)            
         )
        (else
         ;only if the direction is backward
         (set! right #t) (set! left #t)
         )
        )
  

  ;Infrared
  (set-point-x! ir0 (+ x (* 18 (cos (+ z 0.2)))))
  (set-point-y! ir0 (+ y (* -1 18 (sin (+ z 0.2)))))
  (set-point-intx! ir0 (exact-round (point-x ir0)))
  (set-point-inty! ir0 (exact-round (point-y ir0)))
  
  (set-point-x! ir1 (+ x (* 18 cosz)))
  (set-point-y! ir1 (+ y (* -1 18 sinz)))
  (set-point-intx! ir1 (exact-round (point-x ir1)))
  (set-point-inty! ir1 (exact-round (point-y ir1)))
  
  (set-point-x! ir2 (+ x (* 18 (cos (- z 0.2)))))
  (set-point-y! ir2 (+ y (* -1 18 (sin (- z 0.2)))))
  (set-point-intx! ir2 (exact-round (point-x ir2)))
  (set-point-inty! ir2 (exact-round (point-y ir2)))

  ;color extraction
  (set-point-black! ir0 (not (eq? #f (member (+ (* HEIGHT (point-inty ir0)) (point-intx ir0)) blacks))))
  (set-point-black! ir1 (not (eq? #f (member (+ (* HEIGHT (point-inty ir1)) (point-intx ir1)) blacks))))
  (set-point-black! ir2 (not (eq? #f  (member (+ (* HEIGHT (point-inty ir2)) (point-intx ir2)) blacks))))

  ;euclidean vector
  (set-destination-x! direction (+ x (* power 20 cosz)))
  (set-destination-y! direction (+ y (* -1 power 20 sinz)))

  ;left wheel
  (set-line-x1! leftWheel (+ x (* 15 (cos (+ z (/ pi 2) 0.2)))))
  (set-line-y1! leftWheel (+ y (* -1 15 (sin (+ z (/ pi 2) 0.2)))))
  (set-line-x2! leftWheel (+ x (* 15 (cos (+ z (/ pi 2) -0.2)))))
  (set-line-y2! leftWheel (+ y (* -1 15 (sin (+ z (/ pi 2) -0.2)))))
  ;right wheel
  (set-line-x1! rightWheel (+ x (* 15 (cos (- z (/ pi 2) 0.2)))))
  (set-line-y1! rightWheel (+ y (* -1 15 (sin (- z (/ pi 2) 0.2)))))
  (set-line-x2! rightWheel (+ x (* 15 (cos (- z (/ pi 2) -0.2)))))
  (set-line-y2! rightWheel (+ y (* -1 15 (sin (- z (/ pi 2) -0.2)))))
  
)
                       

;windowing
(define frame (new
               (class frame%
                 (super-new [label "Frame"]
                            [style '(no-resize-border)]
                            [width (+ WIDTH 300)]
                            [height HEIGHT]
                            )
                 (define/augment (on-close) (println "closed window") (close-asip))
                 )
               )
  )

(define mainPanel (new horizontal-panel%
                   [parent frame]
                   [min-width (+ WIDTH 300)]	 
                   [min-height HEIGHT]
                   )
  )

(define leftPanel (new panel%
                   [parent mainPanel]
                   [min-width WIDTH]	 
                   [min-height HEIGHT]
                   )
  )

(define rightPanel (new vertical-panel%
                   [parent mainPanel]
                   [min-width 300]	 
                   [min-height HEIGHT]
                   )
  )


;canvas
(define bot (new canvas%
                 [parent leftPanel]
                 [paint-callback
                     (λ (c dc)
                       (send dc clear) ;erease
                       
                       (send dc draw-bitmap bg_img 0 0)
                   
                       
                       ;bumpers
                       (send dc set-pen "red" 3 'solid)
                       ;(cond ( (equal? left #f)
                       (send dc draw-arc (- x 20) (- y 20) 40 40 (+ z 0.2) (+ z (/ pi 4)))
                       ;))
                       ;(cond ( (equal? right #f)
                       (send dc draw-arc (- x 20) (- y 20) 40 40 (- z (/ pi 4)) (- z 0.2))
                       ;))
                       
                       ;base
                       (send dc set-pen "red" 36 'solid)
                       (send dc draw-point x y)

                       ;wheels
                       (send dc set-pen "black" 6 'solid)
                       (send dc draw-line (line-x1 leftWheel) (line-y1 leftWheel) (line-x2 leftWheel) (line-y2 leftWheel)) ; left wheel
                       (send dc draw-line (line-x1 rightWheel) (line-y1 rightWheel) (line-x2 rightWheel) (line-y2 rightWheel)) ; right wheel

                       ;sensors position
                       
                       ;IR
                       (send dc set-pen "black" 2 'solid)
                       (send dc draw-point (point-x ir0) (point-y ir0)) ; left
                       (send dc set-pen "orange" 2 'solid)
                       (send dc draw-point (point-x ir1) (point-y ir1)) ; center
                       (send dc set-pen "blue" 2 'solid)
                       (send dc draw-point (point-x ir2) (point-y ir2)) ; right
                       
                       ;direction euclidean vector
                       (send dc set-pen "black" 2 'solid)
                       (send dc draw-line x y (destination-x direction) (destination-y direction))


                       )]
                 ))



(define (loop) ;should be in a thread
  ;update status bar
  (send frame set-status-text
        (string-append "IR0: " (format "~a" (point-black ir0))
                       " IR1: " (format "~a" (point-black ir1))
                       " IR2: " (format "~a" (point-black ir2))
                       " leftBump: " (format "~a" left)
                       " rightBump: "(format "~a" right)
                       " dir: " (format "~a" delta)
                       ))
  (send bot on-paint)
  (position)
  (sleep/yield 0.05)
  (loop)
  )


(define (read-hook)
  (printf "Read thread started ...")
  (loop))


;;racket-main function mapping

;open the GUI in a thread
(define open-asip
  (lambda ()
    (send frame create-status-line) 
    (send frame show #t)
    ;(send bg on-paint)
    (set! gui-thread (thread (lambda ()  (read-hook))))
    ;(loop)
    )
  )

;close the GUI and the thread
(define close-asip
  (lambda ()
    (when (not (null? gui-thread)) (println "Killing thread .... ") (kill-thread gui-thread))
    ;(exit #t)
    (println "closed")
    )
  )


;; Stopping the motor with utility functions
(define w1-stopMotor
  (λ () (setMotor 0 0))
  )
(define w2-stopMotor
  (λ () (setMotor 1 0))
  )
(define stopMotors
  (λ ()
    (setMotor 0 0)
    (setMotor 1 0)
    )
  )


;; Setting both motors at the same time
(define setMotors
  (λ (s1 s2)
    (setMotor 0 s1)
    (setMotor 1 s2)
    )
  )

(define setMotor
  (λ (m s)
    (cond ( (equal? m 0) (set! leftWheelPwr s))
          ( (equal? m 1) (set! rightWheelPwr s)))
    )
  )


;; Boolean functions for bump sensors
(define rightBump?
  (λ () (cond ( (> bumpersInterval 0 ) right)))
  )
(define leftBump?
    (λ () (cond ( (> bumpersInterval 0 ) left)))
  )

(define enableBumpers
  (λ (interval)
    (set! bumpersInterval interval)
    )
  )