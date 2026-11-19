;;; early-init.el --- Loaded before the first frame -*- lexical-binding: t; -*-

;; Faster startup: no GC while loading, restored in init.el
(setq gc-cons-threshold most-positive-fixnum)

;; Font: size in points as in Windows Terminal. WSLg does not apply Windows
;; display scaling (150% here) to Emacs, so scale it manually.
(defvar my/font-family "Iosevka Term")
(defvar my/font-size 14)
(defvar my/display-scale 1.5)

;; Set UI before the first frame is drawn to avoid flicker/resizing
(setq default-frame-alist
      `((menu-bar-lines . 0)
        (tool-bar-lines . 0)
        (vertical-scroll-bars . nil)
        (font . ,(format "%s-%d" my/font-family
                         (round (* my/font-size my/display-scale))))))
(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(setq inhibit-startup-screen t
      frame-inhibit-implied-resize t)

;;; early-init.el ends here
