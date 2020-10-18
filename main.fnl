;; global parameters and constants

(local RAD (/ math.pi 180.0))
(local DRAW-DISTANCE 1000)
(local MARCH-DELTA 0.0001)
(local MAX-STEPS 500)
(var reflection-count 3)
(var fov 60)

;; window properties & initialization

(local window-width 512)
(local window-height 448)
(local window-flags {:resizable true :vsync false :minwidth 256 :minheight 224})

(fn love.load []
  (love.window.setTitle "LÖVE Raymarching")
  (love.window.setMode window-width window-height window-flags))

;; vector functions

(fn vec3 [x y z]
  (if (not x) [0 0 0]
      (and (not y) (not z)) [x x x]
      [x y (or z 0)]))

(fn vec-length [[x y z]]
  (math.sqrt (+ (^ x 2) (^ y 2) (^ z 2))))

(fn vec-sub [[x0 y0 z0] [x1 y1 z1]]
  [(- x0 x1) (- y0 y1) (- z0 z1)])

(fn vec-add [[x0 y0 z0] [x1 y1 z1]]
  [(+ x0 x1) (+ y0 y1) (+ z0 z1)])

(fn vec-mul [[x0 y0 z0] [x1 y1 z1]]
  [(* x0 x1) (* y0 y1) (* z0 z1)])

(fn vec-div [[x0 y0 z0] [x1 y1 z1]]
  [(/ x0 x1) (/ y0 y1) (/ z0 z1)])

(fn norm [v]
  (let [len (vec-length v)
        [x y z] v]
    [(/ x len) (/ y len) (/ z len)]))

(fn dot [[x0 y0 z0] [x1 y1 z1]]
  (+ (* x0 x1) (* y0 y1) (* z0 z1)))

(fn cross [[x0 y0 z0] [x1 y1 z1]]
  [(- (* y0 z1) (* z0 y1))
   (- (* z0 x1) (* x0 z1))
   (- (* x0 y1) (* y0 x1))])

(fn rotate-point [[x y z] [ax ay az] x-angle z-angle]
  (let [x (- x ax)
        y (- y ay)
        z (- z az)
        x-angle (* x-angle RAD)
        z-angle (* z-angle RAD)
        cos-x (math.cos x-angle)
        sin-x (math.sin x-angle)
        cos-z (math.cos z-angle)
        sin-z (math.sin z-angle)]
    [(+ (* cos-x cos-z x) (* (- sin-x) y) (* cos-x sin-z z) ax)
     (+ (* sin-x cos-z x) (* cos-x y) (- (* sin-x sin-z z)) ay)
     (+ (* (- sin-z) x) (* cos-z z) az)]))

;; objects and distance functions

(fn box-distance [{:pos [box-x box-y box-z]
                   :dimensions [x-side y-side z-side]}
                  [x y z]]
  (math.sqrt (+ (^ (math.max 0 (- (math.abs (- box-x x)) (/ x-side 2))) 2)
           (^ (math.max 0 (- (math.abs (- box-y y)) (/ y-side 2))) 2)
           (^ (math.max 0 (- (math.abs (- box-z z)) (/ z-side 2))) 2))))

(fn box [sides pos color]
  (let [[x y z] (or pos [0 0 0])
        [x-side y-side z-side] (or sides [10 10 10])
        [r g b] (or color [1 1 1])]
    {:dimensions [(or x-side 10)
                  (or y-side 10)
                  (or z-side 10)]
     :pos [(or x 0) (or y 0) (or z 0)]
     :color [(or r 0) (or g 0) (or b 0)]
     :sdf box-distance}))

(fn sphere-distance [{:pos [sx sy sz] : radius} [x y z]]
  (- (math.sqrt (+ (^ (- sx x) 2) (^ (- sy y) 2) (^ (- sz z) 2)))
     radius))

(fn sphere [radius pos color]
  (let [[x y z] (or pos [0 0 0])
        [r g b] (or color [1 1 1])]
    {:radius (or radius 5)
     :pos [(or x 0) (or y 0) (or z 0)]
     :color [(or r 0) (or g 0) (or b 0)]
     :sdf sphere-distance}))

(fn ground-plane [z color]
  (let [[r g b] (or color [1 1 1])]
    {:z (or z 0)
     :color [(or r 0) (or g 0) (or b 0)]
     :sdf (fn [plane [_ _ z]] (- z plane.z))}))

;; raymarching

(fn distance-estimator [point scene]
  (var min DRAW-DISTANCE)
  (var color [0 0 0])
  (each [_ object (ipairs scene)]
    (let [distance (object:sdf point)]
      (when (< distance min)
        (set min distance)
        (set color (. object :color)))))
  (values min color))

(fn move-point [point dir distance]
  (vec-add point (vec-mul dir (vec3 distance))))

(fn march-ray [origin direction scene]
  (var [steps distance color] [0 0 nil])
  (var not-done? true)
  (while not-done?
    (let [(new-distance
           new-color) (-> origin
                          (move-point direction distance)
                          (distance-estimator scene))]
      (when (or (< new-distance MARCH-DELTA)
                (>= distance DRAW-DISTANCE)
                (> steps MAX-STEPS))
        (set not-done? false))
      (set distance (+ distance new-distance))
      (set color new-color)
      (set steps (+ steps 1))))
  (values distance color steps))

;; lightning and reflections

(fn get-normal [[px py pz] scene]
  (let [x MARCH-DELTA
        (d) (distance-estimator [px py pz] scene)
        (dx) (distance-estimator [(- px x) py pz] scene)
        (dy) (distance-estimator [px (- py x) pz] scene)
        (dz) (distance-estimator [px py (- pz x)] scene)]
    (norm [(- d dx) (- d dy) (- d dz)])))

(fn clamp [a l t]
  (if (< a l) l
      (> a t) t
      a))

(fn above-surface-point [point normal]
  (vec-add point (vec-mul normal (vec3 (* MARCH-DELTA 2)))))

(fn point-lightness [point scene light]
  (let [normal (get-normal point scene)
        light-vec (norm (vec-sub light point))
        (distance) (march-ray (above-surface-point point normal)
                              light-vec
                              scene)
        lightness (clamp (dot light-vec normal) 0 1)]
    (if (< distance DRAW-DISTANCE)
        (* lightness 0.5)
        lightness)))

(fn reflection-color [color point direction scene light]
  (var [color p d i n] [color point direction 1 (get-normal point scene)])
  (var not-done? true)
  (while (and (<= i reflection-count) not-done?)
    (let [r (vec-sub d (vec-mul (vec-mul (vec3 (dot d n)) n) [2 2 2]))
          (distance new-color) (march-ray (above-surface-point p n) r scene)]
      (if (< distance DRAW-DISTANCE)
          (do (set p (move-point p r distance))
              (set n (get-normal p scene))
              (set d r)
              (let [l (* (point-lightness p scene light) 0.5)]
                (set color (vec-mul (vec-add color (vec-mul new-color (vec3 l)))
                                    (vec3 0.66)))))
          (do (set color (vec-div (vec-add color (vec-div scene.env-color (vec3 i))) (vec3 2)))
              (set not-done? false))))
    (set i (+ i 1)))
  color)

(fn shade-point [point direction color scene light]
  (-> color
      (vec-mul (vec3 (point-lightness point scene light)))
      (reflection-color point direction scene light)))

;; scene, light, and camera

(local scene [(box [5 5 5] [-2.7 -2 2.5] [0.79 0.69 0.59])
              (box [5 5 5] [2.7 2 2.5] [0.75 0.08 0.66])
              (box [5 5 5] [0 0 7.5] [0.33 0.73 0.42])
              (sphere 2.5 [-2.7 2.5 2.5] [0.56 0.11 0.05])
              (sphere 10 [6 -20 10] [0.97 0.71 0.17])
              (ground-plane 0 [0.97 0.27 0.35])])

(set scene.env-color [0.901 0.976 1])

(var light [-30 20 20])

(fn move-light []
  (set light (rotate-point light [0 0 0] 1 0)))

(local camera {:pos [20 50 20]
               :x-rotate 255
               :z-rotate 15})

(fn forward-vec [camera]
  (let [pos camera.pos]
    (rotate-point (vec-add pos [1 0 0]) pos camera.x-rotate camera.z-rotate)))

(fn camera-forward [n]
  (let [dir (norm (vec-sub (forward-vec camera) camera.pos))]
    (set camera.pos (move-point camera.pos dir n))))

(fn camera-elevate [n]
  (set camera.pos (vec-add camera.pos [0 0 n])))

(fn camera-rotate-x [x]
  (set camera.x-rotate (% (- camera.x-rotate x) 360)))

(fn camera-rotate-z [z]
  (set camera.z-rotate (clamp (+ camera.z-rotate z) -89.9 89.9)))

(fn camera-strafe [x]
  (let [z-rotate camera.z-rotate]
    (set camera.z-rotate 0)
    (camera-rotate-x 90)
    (camera-forward x)
    (camera-rotate-x -90)
    (set camera.z-rotate z-rotate)))

(fn inc-fov [x]
  (set fov (clamp (+ fov x) 30 120)))

(fn inc-reflections [x]
  (set reflection-count (clamp (+ reflection-count x) 0 10)))

;; drawing

(fn love.draw []
  (let [(width height) (love.graphics.getDimensions)
        projection-distance (/ 1 (math.tan (* (/ fov 2) RAD)))
        ro camera.pos
        lookat (forward-vec camera)
        f (norm (vec-sub lookat ro))
        c (vec-add ro (vec-mul f (vec3 projection-distance)))
        r (norm (cross [0 0 -1] f))
        u (cross f r)]
    (for [y 0 height]
      (for [x 0 width]
        (let [uv-x (* (- (/ x width) 0.5) (/ width height))
              uv-y (- (/ y height) 0.5)
              i (vec-add c (vec-add
                            (vec-mul r (vec3 uv-x))
                            (vec-mul u (vec3 uv-y))))
              rd (norm (vec-sub i ro))
              (distance color) (march-ray ro rd scene)]
          (if (< distance DRAW-DISTANCE)
              (let [point (move-point ro rd distance)]
                (love.graphics.setColor (shade-point point rd color scene light)))
              (love.graphics.setColor scene.env-color))
          (love.graphics.points x y))))))

;; user input

(var gamepad nil)

(fn love.joystickadded [joystick]
  (set gamepad joystick))

(fn handle-controller []
  (when gamepad
    (let [lstick-x  (gamepad:getGamepadAxis "leftx")
          lstick-y  (gamepad:getGamepadAxis "lefty")
          l2        (gamepad:getGamepadAxis "triggerleft")
          rstick-x  (gamepad:getGamepadAxis "rightx")
          rstick-y  (gamepad:getGamepadAxis "righty")
          r2        (gamepad:getGamepadAxis "triggerright")
          up        (gamepad:isGamepadDown  "dpup")
          down      (gamepad:isGamepadDown  "dpdown")
          l1        (gamepad:isGamepadDown  "leftshoulder")
          r1        (gamepad:isGamepadDown  "rightshoulder")]
      (when (and lstick-y (or (< lstick-y -0.2) (> lstick-y 0.2)))
        (camera-forward (* 2 (- lstick-y))))
      (when (and lstick-x (or (< lstick-x -0.2) (> lstick-x 0.2)))
        (camera-strafe (* 2 lstick-x)))
      (when (and rstick-x (or (< rstick-x -0.2) (> rstick-x 0.2)))
        (camera-rotate-x (* 4 rstick-x)))
      (when (and rstick-y (or (< rstick-y -0.2) (> rstick-y 0.2)))
        (camera-rotate-z (* 4 rstick-y)))
      (when (and r2 (> r2 -0.8))
        (camera-elevate (+ 1 r2)))
      (when (and l2 (> l2 -0.8))
        (camera-elevate (- (+ 1 l2))))
      (if up   (inc-fov -1)
          down (inc-fov 1))
      (if l1 (inc-reflections -1)
          r1 (inc-reflections 1)))))

(fn handle-keyboard-input []
  (if (love.keyboard.isDown "w") (camera-forward 1)
      (love.keyboard.isDown "s") (camera-forward -1))
  (if (love.keyboard.isDown "d")
      (if (love.keyboard.isDown "lshift")
          (camera-strafe 1)
          (camera-rotate-x 1))
      (love.keyboard.isDown "a")
      (if (love.keyboard.isDown "lshift")
          (camera-strafe -1)
          (camera-rotate-x -1)))
  (if (love.keyboard.isDown "q") (camera-rotate-z 1)
      (love.keyboard.isDown "e") (camera-rotate-z -1))
  (if (love.keyboard.isDown "r") (camera-elevate 1)
      (love.keyboard.isDown "f") (camera-elevate -1))
  (if (love.keyboard.isDown "o") (inc-fov 1)
      (love.keyboard.isDown "p") (inc-fov -1))
  (if (love.keyboard.isDown "k") (inc-reflections 1)
      (love.keyboard.isDown "l") (inc-reflections -1)))

(fn love.update [dt]
  (move-light light)
  (handle-keyboard-input)
  (handle-controller))
