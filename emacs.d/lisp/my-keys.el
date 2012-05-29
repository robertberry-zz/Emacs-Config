; Global key bindings here. Mode specific keybindings in their own config files.

(require 'my-utils)

(defvar my-key-settings
  (list
   ;;; Nice alias for a frequently used command
   "\C-x\C-m" 'execute-extended-command
   "\C-c\C-m" 'execute-extended-command
   ;;; Backspace is in an awkward place, alias it to C-w
   "\C-w" 'backward-delete-char-untabify
   ;;; So now move kill-region to C-x C-k
   "\C-x\C-k" 'kill-region
   "\C-c\C-k" 'kill-region
   ;;; Org-specific
   "\C-cl" 'org-store-link
   "\C-ca" 'org-agenda
   ;;; Spelling
   "\C-c\C-p" 'flyspell-check-previous-highlighted-word
   ;;; Version control
   "\C-cg" 'magit-status
   ))

(defvar my-key-unsettings
  (list
   ;;; I never change the fill column on purpose
   "\C-xf"
   ))

(mapapply 'global-set-key (pairs my-key-settings))
(mapcar 'global-unset-key my-key-unsettings)
