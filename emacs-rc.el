; I've refactored a lot of this out into separate files under ~/.emacs.d/lisp

(require 'cl)

(defvar emacs-root "/home/robert/.emacs.d/")

(add-to-list 'load-path (concat emacs-root "lisp"))

(mapcar 'load-library '("my-utils"
                        "my-modes"
                        "my-config"
                        "perl-config"
                        "org-config"
                        "email-config"
                        "my-display"
                        "my-keys"))

;; Use Emacs client
(server-start)
