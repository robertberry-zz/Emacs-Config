; Global config stuff

(setq user-mail-address "robert.berry@liverpool.ac.uk")
(setq user-full-name "Robert Berry")

(put 'set-goal-column 'disabled nil)
(put 'upcase-region 'disabled nil)

;; why the heck is this not on by default - allows emacs c&p to work across
;; x windows
(setq x-select-enable-clipboard t)

;; prevent ediff's dumb behaviour of using a separate window (wtf? when
;; pretty much everything else in emacs uses buffers? why would you do this??)

(setq ediff-window-setup-function 'ediff-setup-windows-plain)

(setq-default fill-column 78)

;; Set up spacing
(defun my-tab-settings ()
  "Sets tab settings to four spaces"
  (interactive)
  (progn (setq c-basic-offset 4)
		 (setq tab-width 4)
		 (setq-default indent-tabs-mode nil)))

(my-tab-settings)

;; turn on autofill by default
(mapcar (lambda (hook) (add-hook hook 'turn-on-auto-fill))
        '(python-mode-hook
          text-mode-hook
          ruby-mode-hook
          c-mode-hook
          org-mode-hook
	  perl-mode-hook
          sh-mode-hook
          cperl-mode-hook
	  emacs-lisp-mode-hook
          c++-mode-hook
          markdown-mode-hook
          coffee-mode-hook))
;; I'm sure there must be a way to automatically do this to any code modes but
;; I've not yet found it. - text mode hook? do code modes inherit from this?
;; :<

