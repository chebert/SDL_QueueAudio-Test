sdl-c: sdl.c
	gcc -o sdl sdl.c -lSDL2 -lm
	./sdl

sdl-lisp: sdl.lisp
	sbcl --load "sdl.lisp" --eval "(quit)"
