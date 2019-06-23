(in-package :cl-user)

(use-package :sb-alien)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (load-shared-object
   #+linux "libSDL2-2.0.so"
   #+win32 "./SDL.dll"))

(defparameter *fps* 60)

(defun power-of-2? (n)
  (zerop (logand n (1- n))))

(defparameter *nullptr* (sb-sys:int-sap 0))

;;; SDL
(defparameter *sdl-init-everything* #x0000ffff)
(define-alien-routine ("SDL_Init" sdl-init!) int
  (flag int))
(define-alien-routine ("SDL_Quit" sdl-quit!) void)

(define-alien-routine ("SDL_Delay" sdl-delay!) void
  (ms unsigned-int))

;;; SDL Audio

#||
typedef struct SDL_AudioSpec
{
    int freq;
    SDL_AudioFormat format;
    Uint8 channels;
    Uint8 silence;
    Uint16 samples;
    Uint16 padding;
    Uint32 size;
    SDL_AudioCallback callback;
    void *userdata;
} SDL_AudioSpec;
||#

(define-alien-type nil
    (struct sdl-audio-spec
	    (freq int)
	    (format unsigned-short)
	    (channels unsigned-char)
	    (silence unsigned-char)
	    (samples unsigned-short)
	    (padding unsigned-short)
	    (size unsigned-int)
	    (callback system-area-pointer)
	    (user-data system-area-pointer)))

(define-alien-routine ("SDL_OpenAudio" sdl-open-audio!) unsigned-int
  (desired (* (struct sdl-audio-spec)))
  (obtained (* (struct sdl-audio-spec))))

(define-alien-routine ("SDL_CloseAudio" sdl-close-audio!) void)

(define-alien-routine ("SDL_QueueAudio" sdl-queue-audio!) int
  (device-id unsigned-int)
  (data system-area-pointer)
  (length unsigned-int))
(define-alien-routine ("SDL_GetQueuedAudioSize" sdl-get-queued-audio-size!) unsigned-int
  (device-id unsigned-int))

(define-alien-routine ("SDL_PauseAudio" sdl-pause-audio!) void
  (pause-on int))

(defparameter *sdl-audio-s16le* #x8010)

;;; Application Audio
(defparameter *samples/second* 44100)
(defparameter *channels/sample* 2)
(defparameter *frames/buffer* 6)
(defparameter *bytes/channel* 2)
(defparameter *audio-format* *sdl-audio-s16le*)
(defparameter *s16-max* (1- (expt 2 15)))

(defun bytes/sample ()
  "Number of bytes in a mulit-channel sample of audio."
  (* *bytes/channel* *channels/sample*))
(defun seconds/frame ()
  "Number of seconds in a frame (1/60)."
  (/ *fps*))
(defun samples/frame ()
  "Number of samples a frame (1/fps seconds) of audio has."
  (* *samples/second* (seconds/frame)))
(defun bytes/frame ()
  "Number of bytes a frame (1/fps seconds) of audio has."
  (* (samples/frame) (bytes/sample)))
(defun samples/buffer ()
  "Size of the audio buffer in samples."
  (* (samples/frame) *frames/buffer*))
(defun bytes/buffer ()
  "Size of the audio buffer in bytes."
  (* (bytes/sample) (samples/buffer)))

(defun ms/buffer ()
  "The amount of time in milliseconds a buffer of audio would last."
  (* *frames/buffer* (seconds/frame) 1000))

(defun open-audio! (&key (samples/second *samples/second*)
		      (channels/sample *channels/sample*)
		      (format *audio-format*)
		      (samples/audio-buffer 4096))
  "Open the audio device with the specified parameters."
  (assert (power-of-2? samples/audio-buffer))
  (with-alien ((spec (struct sdl-audio-spec)))
    (setf (slot spec 'freq) samples/second
	  (slot spec 'format) format
	  (slot spec 'channels) channels/sample
	  (slot spec 'silence) 0
	  (slot spec 'samples) samples/audio-buffer
	  (slot spec 'size) 0
	  (slot spec 'callback) *nullptr*
	  (slot spec 'user-data) *nullptr*)
    (sdl-open-audio! (addr spec) *nullptr*)))

(defun sin-audio-sample (volume frequency sample-idx)
  "Return a s16 sample of audio. Time is based on the running sample-idx."
  (let* ((time (/ sample-idx *samples/second*)))
    (round (* (* volume *s16-max*) (sin (* 2 pi frequency time))))))

(defun test-audio! ()
  (sdl-init! *sdl-init-everything*)
  (open-audio!)
  (sdl-pause-audio! 0)
  (let ((sample-idx 0)
	(device-id 1)
	(volume 0.1)
	(app-duration 3))
    (loop for i below (* *fps* app-duration)
       do
	 (let* ((bytes-written (sdl-get-queued-audio-size! device-id))
		(bytes-to-write (max 0 (- (bytes/buffer) bytes-written)))
		(samples-to-write (truncate bytes-to-write (bytes/sample)))

		(sound-buffer (make-alien
			       short
			       (truncate bytes-to-write *channels/sample*))))
	   (print bytes-written)
	   (loop for idx below samples-to-write do
		(setf (deref sound-buffer (* idx 2))
		      (sin-audio-sample volume 440 sample-idx))
		(setf (deref sound-buffer (1+ (* idx 2)))
		      (sin-audio-sample volume 880 sample-idx))
		(incf sample-idx))
	   (sdl-queue-audio! device-id (alien-sap sound-buffer) bytes-to-write)
	   (free-alien sound-buffer))

	 (sdl-delay! 16)))
  (sdl-close-audio!)
  (sdl-quit!))

(test-audio!)
