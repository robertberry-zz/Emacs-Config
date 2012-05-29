;; Settings for org-mode

(require 'my-utils)

; list of directories from which to import todos for agendas
(defvar my-org-directories
  (list
   "~/org/Diary/2012/"
   "~/org/projects/"
   ))

(defun my-org-files ()
  (mappend '(lambda (directory)
              (directory-files directory t "\\.org$"))
           my-org-directories))

(setq org-log-done 'note)
(setq org-agenda-files (my-org-files))
