; General mode set up. Bigger modes tend to get their own files.

;; util
(defmacro add-items (seq items)
  `(setq ,seq (append ,items ,seq)))

;; Set up mode load paths
(add-items load-path '("~/.emacs.d/vendor"
                       "~/.emacs.d/vendor/coffee-mode"
                       "~/.emacs.d/vendor/haskell-mode"
                       "~/.emacs.d/vendor/magit-mode"
                       "/usr/share/emacs23/site-lisp/emacs-goodies-el/"))

;; Require modes
(mapcar 'require '(ido
                   sass-mode
                   yaml-mode
                   cperl-mode
                   color-theme-tango
                   markdown-mode
                   coffee-mode
                   stumpwm-mode
                   org-install
                   magit
                   yasnippet-bundle
                   perlcritic
                   utils
                   quack))

;; File extension mode mappings
(add-items auto-mode-alist '(("\\.rake$" . ruby-mode)
                             ("capfile$" . ruby-mode)
                             ("\\.stumpwmrc$" . stumpwm-mode)
                             ("Guardfile$" . ruby-mode)
                             ("Rakefile$" . ruby-mode)
                             ("Gemfile$" . ruby-mode)
                             ("\\.tac" . python-mode)
                             ("\\.t$" . cperl-mode)
                             ("\\.tpl$" . html-mode)
                             ("\\.yml$" . yaml-mode)
                             ("\\.conkerorrc$" . javascript-mode)
                             ("Cakefile" . coffee-mode)
                             (".coffee" . coffee-mode)
                             ("\\.markdown$" . markdown-mode)))


;; initialize Haskell
(load "haskell-site-file")

(add-hook 'haskell-mode-hook 'turn-on-haskell-doc-mode)
(add-hook 'haskell-mode-hook 'turn-on-haskell-indentation)

;; initialize YaSnippet
(yas/initialize)
(yas/load-directory "~/.emacs.d/snippets")

(defun coffee-custom ()
  "coffee-mode-hook"
 (set (make-local-variable 'tab-width) 2))

(add-hook 'coffee-mode-hook
  '(lambda() (coffee-custom)))

;; make the repl able to import from current dir in python
(setq python-remove-cwd-from-path nil)

;; set up IDO mode
(ido-mode t)
(setq ido-enable-flex-matching t) ; turn on fuzzy matching

;; disable auto searching for files unless called explicitly
(setq ido-auto-merge-delay-time 99999)

;; Use C-c C-s to search
(define-key ido-file-dir-completion-map (kbd "C-c C-s") 
  (lambda() 
    (interactive)
    (ido-initiate-auto-merge (current-buffer))))

;; Screw the too-big message. This is 2012 D:
(setq ido-max-directory-size 100000)

;; set up flyspell mode

;; for text files
(dolist (hook '(text-mode-hook))
  (add-hook hook (lambda () (flyspell-mode 1))))

;; for source files
(dolist (hook '(python-mode-hook
                javascript-mode-hook))
  (add-hook hook (lambda () (flyspell-prog-mode))))

;; fix spelling for org mode (the visibility cycling breaks it)
(add-hook 'org-cycle-hook (lambda (visibility) (flyspell-buffer)))

;; performance increase
(setq flyspell-issue-message-flag nil)

