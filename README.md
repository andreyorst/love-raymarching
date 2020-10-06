# LÖVE Raymarching
A rather simple and quite slow implementation of ray marching algorithm from [this post](https://andreyorst.gitlab.io/posts/2020-10-15-raymarching-with-fennel-and-love/ "Raymarching with Fennel and LÖVE") in [Fennel][1] language, using [LÖVE][2] - a [Lua][3] game engine.
It was built against LÖVE 11.3 and Fennel 0.6.0 on Lua 5.3.

![screenshot][4]

## Build
Simply run this command:

    $ fennel --compile main.fnl > main.lua

## Run
Execute `love .` in the root directory of the project.

## Movement
Simple movement inputs are available using keyboard:

- <kbd>w</kbd>, <kbd>s</kbd> - move forward and backward
- <kbd>a</kbd>, <kbd>d</kbd> - rotate left and right
- <kbd>Shift+a</kbd>, <kbd>Shift+d</kbd> - strafe left and right
- <kbd>q</kbd>, <kbd>e</kbd> - rotate up and down
- <kbd>r</kbd>, <kbd>f</kbd> - elevate
- <kbd>o</kbd>, <kbd>p</kbd> - change field of view (FOV)
- <kbd>k</kbd>, <kbd>k</kbd> - change amount of reflections

#### Controller input
PS4 controller is supported, other controllers are untested, but probably should work.
Button mapping:

- Left stick up and down - move forward and backward
- Left stick left and right - strafe left and right
- Right stick - camera control
- L2 and R2 - elevate
- DPad Up and Down - change FOV
- L1 and R1 - change amount of reflections

[1]: https://fennel-lang.org/
[2]: https://love2d.org/
[3]: https://www.lua.org/
[4]: screenshot.png
