;;; haskell-process.el -- Communicating with the inferior Haskell process.

;; Copyright (C) 2011-2012 Chris Done

;; Author: Chris Done <chrisdone@gmail.com>

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;;; Todo:

;;; Code:

(require 'haskell-mode)
(require 'haskell-interactive-mode)
(require 'haskell-session)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Configuration

(defcustom haskell-process-path-ghci
  (or (cond
       ((not (fboundp 'executable-find)) nil)
       ((executable-find "hugs") "hugs \"+.\"")
       ((executable-find "ghci") "ghci"))
      "ghci")
  "The path for starting ghci."
  :group 'haskell
  :type '(choice string (repeat string)))

(defcustom haskell-process-path-cabal-dev
  "cabal-dev"
  "The path for starting cabal-dev."
  :group 'haskell
  :type '(choice string (repeat string)))

(defcustom haskell-process-type
  'ghci
  "The inferior Haskell process type to use."
  :options '(ghci cabal-dev)
  :type 'symbol
  :group 'haskell)

(defcustom haskell-notify-p
  nil
  "Notify using notify.el (if loaded)?"
  :type 'boolean
  :group 'haskell)

(defcustom haskell-process-suggest-no-warn-orphans
  t
  "Suggest adding -fno-warn-orphans pragma to file when getting orphan warnings."
  :type 'boolean
  :group 'haskell)

(defcustom haskell-process-suggest-overloaded-strings
  t
  "Suggest adding OverloadedStrings pragma to file when getting type mismatches with [Char]."
  :type 'boolean
  :group 'haskell)

(defvar haskell-process-prompt-regex "\\(^[> ]*> $\\|\n[> ]*> $\\)")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Specialised commands

(defun haskell-process-clear ()
  "Clear the current process."
  (interactive)
  (haskell-process-reset (haskell-process)))

(defun haskell-process-generate-tags (&optional and-then-find-this-tag)
  "Regenerate the TAGS table."
  (interactive)
  (let ((process (haskell-process)))
    (haskell-process-queue-command
     process
     (haskell-command-make
      (cons process and-then-find-this-tag)
      (lambda (state)
        (haskell-process-send-string
         (car state)
         (format ":!cd %s && %s | %s | %s"
                 (haskell-session-cabal-dir (haskell-process-session (car state)))
                 "find . -name '*.hs*'"
                 "grep -v '#'" ; To avoid Emacs back-up files. Yeah.
                 "xargs hasktags -e -x")))
      nil
      (lambda (state response)
        (when (cdr state)
          (let ((tags-file-name
                 (haskell-session-tags-filename (haskell-process-session (car state)))))
            (find-tag (cdr state))))
        (haskell-mode-message-line "Tags generated."))))))

(defun haskell-process-do-type (&optional insert-value)
  "Print the type of the given expression."
  (interactive "P")
  (haskell-process-do-simple-echo
   insert-value
   (format ":type %s" (haskell-ident-at-point))))

(defun haskell-process-do-info (&optional ident)
  "Print the info of the given expression."
  (interactive)
  (haskell-process-do-simple-echo
   nil
   (format ":info %s" (or ident
                          (haskell-ident-at-point)))))

(defun haskell-process-do-try-info (sym)
  "Get info of `sym' and echo in the minibuffer."
  (let ((process (haskell-process)))
    (haskell-process-queue-command
     process
     (haskell-command-make
      (cons process sym)
      (lambda (state)
        (haskell-process-send-string (car state)
                                     (if (string-match "^[A-Za-z_]" (cdr state))
                                         (format ":info %s" (cdr state))
                                       (format ":info (%s)" (cdr state)))))
      nil
      (lambda (process response)
        (unless (or (string-match "^Top level" response)
                    (string-match "^<interactive>" response))
          (haskell-mode-message-line response)))))))

(defun haskell-process-do-simple-echo (insert-value line)
  "Send some line to GHCi and echo the result in the REPL and minibuffer."
  (let ((process (haskell-process)))
    (haskell-process-queue-command
     process
     (haskell-command-make
      (list process line insert-value)
      (lambda (state)
        (haskell-process-send-string (car state) (cadr state)))
      nil
      (lambda (state response)
        (haskell-interactive-mode-echo (haskell-process-session (car state))
                                       response)
        (haskell-mode-message-line response)
        (when (caddr state)
          (goto-char (line-beginning-position))
          (insert (format "%s\n" response))))))))

;;;###autoload
(defun haskell-process-load-file ()
  "Load the current buffer file."
  (interactive)
  (save-buffer)
  (haskell-process-file-loadish (concat "load " (buffer-file-name))))

;;;###autoload
(defun haskell-process-reload-file ()
  "Load the current buffer file."
  (interactive)
  (save-buffer)
  (haskell-process-file-loadish "reload"))

(defun haskell-process-file-loadish (command)
  (let ((session (haskell-session))
        (process (haskell-process)))
    (haskell-session-current-dir session)
    (haskell-process-queue-command
     process
     (haskell-command-make 
      (list session process command)
      (lambda (state)
        (haskell-process-send-string (cadr state)
                                     (format ":%s" (caddr state))))
      (lambda (state buffer)
        (haskell-process-live-build (cadr state) buffer nil))
      (lambda (state response)
        (haskell-process-load-complete (car state) (cadr state) response))))))

;;;###autoload
(defun haskell-process-cabal-build ()
  "Build the Cabal project."
  (interactive)
  (haskell-process-do-cabal "build"))

;;;###autoload
(defun haskell-process-cabal ()
  "Prompts for a Cabal command to run."
  (interactive)
  (haskell-process-do-cabal
   (ido-completing-read "Cabal command: "
                        haskell-cabal-commands)))

(defun haskell-process-do-cabal (command)
  "Run a Cabal command."
  (let ((process (haskell-process)))
    (haskell-process-queue-command
     process
     (haskell-command-make
      (list (haskell-session) process command 0)
      (lambda (state)
        (haskell-process-send-string
         (cadr state)
         (format ":!%s && %s"
                 (format "cd %s" (haskell-session-cabal-dir (car state)))
                 (format "%s %s"
                         (ecase haskell-process-type
                           ('ghci "cabal")
                           ('cabal-dev "cabal-dev"))
                         (caddr state)))))
      (lambda (state buffer)
        (cond ((or (string= (caddr state) "build")
                   (string= (caddr state) "install"))
               (haskell-process-live-build (cadr state) buffer t))
              (t
               (haskell-process-cabal-live state buffer))))
      (lambda (state response)
        (let* ((process (cadr state))
               (session (haskell-process-session process))
               (message-count 0)
               (cursor (haskell-process-response-cursor process)))
          (haskell-process-set-response-cursor process 0)
          (while (haskell-process-errors-warnings session process response)
            (setq message-count (1+ message-count)))
          (haskell-process-set-response-cursor process cursor)
          (let ((msg (format "Complete: cabal %s (%s compiler messages)"
                             (caddr state)
                             message-count)))
            (haskell-interactive-mode-echo session msg)
            (haskell-mode-message-line msg)
            (when (and haskell-notify-p
                       (fboundp 'notify))
              (notify (format "*%s*" (haskell-session-name (car state)))
                      msg)))))))))

(defun haskell-process-cabal-live (state buffer)
  "Do live updates for Cabal processes."
  (haskell-interactive-mode-insert
   (haskell-process-session (cadr state))
   (replace-regexp-in-string
    haskell-process-prompt-regex
    ""
    (substring buffer (cadddr state))))
  (setf (cdddr state) (list (length buffer)))
  nil)

(defun haskell-process-load-complete (session process buffer)
  "Handle the complete loading response."
  (cond ((haskell-process-consume process "Ok, modules loaded: \\(.+\\)$")
         (let ((cursor (haskell-process-response-cursor process)))
           (haskell-process-set-response-cursor process 0)
           (let ((warning-count 0))
             (while (haskell-process-errors-warnings session process buffer)
               (setq warning-count (1+ warning-count)))
             (haskell-process-set-response-cursor process cursor)
             (haskell-mode-message-line "OK."))))
        ((haskell-process-consume process "Failed, modules loaded: \\(.+\\)$")
         (let ((cursor (haskell-process-response-cursor process)))
           (haskell-process-set-response-cursor process 0)
           (while (haskell-process-errors-warnings session process buffer))
           (haskell-process-set-response-cursor process cursor)
           (haskell-interactive-mode-compile-error session "Compilation failed.")))))

(defun haskell-process-live-build (process buffer echo-in-repl)
  "Show live updates for loading files."
  (cond ((haskell-process-consume
          process
          (concat "\\[[ ]*\\([0-9]+\\) of \\([0-9]+\\)\\]"
                  " Compiling \\([^ ]+\\)[ ]+"
                  "( \\([^ ]+\\), \\([^ ]+\\) )[\r\n]+"))
         (haskell-interactive-show-load-message
          (haskell-process-session process)
          'compiling
          (match-string 3 buffer)
          (match-string 4 buffer)
          echo-in-repl)
         t)
        ((haskell-process-consume process "Loading package \\([^ ]+\\) ... linking ... done.\n")
         (haskell-mode-message-line
          (format "Loading: %s"
                  (match-string 1 buffer)))
         t)
        ((haskell-process-consume
          process
          "^Preprocessing executables for \\(.+?\\)\\.\\.\\.")
         (let ((msg (format "Preprocessing: %s" (match-string 1 buffer))))
           (haskell-interactive-mode-echo
            (haskell-process-session process)
            msg)
           (haskell-mode-message-line msg)))
        ((haskell-process-consume process "Linking \\(.+?\\) \\.\\.\\.")
         (let ((msg (format "Linking: %s" (match-string 1 buffer))))
           (haskell-interactive-mode-echo (haskell-process-session process) msg)
           (haskell-mode-message-line msg)))
        ((haskell-process-consume process "\nBuilding \\(.+?\\)\\.\\.\\.")
         (let ((msg (format "Building: %s" (match-string 1 buffer))))
           (haskell-interactive-mode-echo
            (haskell-process-session process)
            msg)
           (haskell-mode-message-line msg)))))

(defun haskell-process-errors-warnings (session process buffer)
  "Trigger handling type errors or warnings."
  (cond
   ((haskell-process-consume
     process
     (concat "[\r\n]\\([^ \r\n:][^:\n\r]+\\):\\([0-9]+\\):\\([0-9]+\\):"
             "[ \n\r]+\\([[:unibyte:][:nonascii:]]+?\\)\n[^ ]"))
    (haskell-process-set-response-cursor process
                                         (- (haskell-process-response-cursor process) 1))
    (let* ((buffer (haskell-process-response process))
           (error-msg (match-string 4 buffer))
           (file (match-string 1 buffer))
           (line (match-string 2 buffer))
           (col (match-string 3 buffer))
           (warning (string-match "^Warning: " error-msg))
           (final-msg (format "%s:%s:%s: %s" 
                              (haskell-session-strip-dir session file)
                              line
                              col
                              error-msg)))
      (funcall (if warning
                   'haskell-interactive-mode-compile-warning
                 'haskell-interactive-mode-compile-error)
               session final-msg)
      (unless warning
        (haskell-mode-message-line final-msg))
      (haskell-process-trigger-extension-suggestions session error-msg file))
    t)))

(defun haskell-process-trigger-extension-suggestions (session msg file)
  "Trigger prompting to add any extension suggestions."
  (cond ((string-match "\\-X\\([A-Z][A-Za-z]+\\)" msg)
         (haskell-process-suggest-pragma "LANGUAGE" (match-string 1 msg)))
        ((string-match "Warning: orphan instance: " msg)
         (when haskell-process-suggest-no-warn-orphans
           (haskell-process-suggest-pragma "OPTIONS" "-fno-warn-orphans")))
        ((string-match "against inferred type `\\[Char\\]'" msg)
         (when haskell-process-suggest-overloaded-strings
           (haskell-process-suggest-pragma "LANGUAGE" "OverloadedStrings")))))

(defun haskell-process-suggest-pragma (pragma extension)
  "Suggest to add something to the top of the file."
  (let ((string  (format "{-# %s %s #-}" pragma extension)))
    (when (y-or-n-p (format "Add %s to the top of the file? " string))
      (find-file (cond ((file-exists-p (concat (haskell-session-current-dir session) "/" file))
                        (concat (haskell-session-current-dir session) "/" file))
                       ((file-exists-p (concat (haskell-session-cabal-dir session) "/" file))
                        (concat (haskell-session-cabal-dir session) "/" file))
                       (t file)))
      (save-excursion
        (goto-char (point-min))
        (insert (concat string "\n"))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Building the process

;;;###autoload
(defun haskell-process-start (session)
  "Start the inferior Haskell process."
  (let ((process (haskell-process-make (haskell-session-name session))))
    (haskell-session-set-process session process)
    (haskell-process-set-session process session)
    (let ((default-directory (haskell-session-cabal-dir session)))
      (unless (haskell-session-get session 'current-dir)
        (haskell-session-set-current-dir session (haskell-process-prompt-dir session)))
      (haskell-process-set-process
       process
       (ecase haskell-process-type
         ('ghci 
          (haskell-process-log (format "Starting inferior GHCi process %s ..."
                                       haskell-process-path-ghci))
          (start-process (haskell-session-name session)
                         nil
                         haskell-process-path-ghci))
         ('cabal-dev
          (let ((dir (concat (haskell-session-cabal-dir session)
                             "/cabal-dev")))
            (haskell-process-log (format "Starting inferior cabal-dev process %s -s %s ..."
                                         haskell-process-path-cabal-dev
                                         dir))
            (start-process (haskell-session-name session)
                           nil
                           haskell-process-path-cabal-dev
                           "ghci"
                           "-s"
                           dir))))))
    (progn (set-process-sentinel (haskell-process-process process) 'haskell-process-sentinel)
           (set-process-filter (haskell-process-process process) 'haskell-process-filter))
    (haskell-process-send-startup process)
    (haskell-process-change-dir session
                                process
                                (haskell-session-current-dir session))
    process))

(defun haskell-process-restart ()
  "Restart the inferior Haskell process."
  (interactive)
  (haskell-process-start (haskell-session)))

(defun haskell-process-make (name)
  "Make an inferior Haskell process."
  (list (cons 'name name)
        (cons 'current-command 'none)))

;;;###autoload
(defun haskell-process ()
  "Get the current process from the current session."
  (haskell-session-process (haskell-session)))

(defun haskell-process-interrupt ()
  "Interrupt the process (SIGINT)."
  (interactive)
  (interrupt-process (haskell-process-process (haskell-process))))

(defun haskell-process-cd (&optional not-interactive)
  "Change directory."
  (interactive)
  (let* ((session (haskell-session))
         (dir (haskell-process-prompt-dir session)))
    (haskell-process-log (format "Changing directory to %s ...\n" dir))
    (haskell-process-change-dir session
                                (haskell-process)
                                dir)))

(defun haskell-process-prompt-dir (session)
  "Prompt for the current directory."
  (read-from-minibuffer
   "Set current directory: "
   (or (haskell-session-get session 'current-dir)
       (if (buffer-file-name)
           (file-name-directory (buffer-file-name))
         "~/"))))

(defun haskell-process-change-dir (session process dir)
  "Change the directory of the current process."
  (haskell-process-queue-command
   process
   (haskell-command-make
    (list session process dir)
    (lambda (state)
      (haskell-process-send-string (cadr state) (format ":cd %s" (caddr state))))
    nil
    (lambda (state _)
      (haskell-session-set-current-dir (car state) (caddr state))
      (haskell-interactive-mode-echo (car state)
                                     (format "Changed directory: %s"
                                             (caddr state)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Process communication

(defun haskell-process-send-startup (process)
  "Send the necessary start messages."
  (haskell-process-queue-command
   process
   (haskell-command-make process
                         (lambda (process)
                           (haskell-process-send-string process ":set prompt \"> \"")
                           (haskell-process-send-string process "Prelude.putStrLn \"\""))
                         nil
                         nil))
  (haskell-process-queue-command
   process
   (haskell-command-make process
                         (lambda (process) (haskell-process-send-string process ":set -v1"))
                         nil
                         (lambda (process _)
                           (haskell-interactive-mode-echo
                            (haskell-process-session process)
                            (nth (random (length haskell-interactive-greetings))
                                 haskell-interactive-greetings))))))

(defun haskell-process-sentinel (proc event)
  "The sentinel for the process pipe."
  (let ((session (haskell-process-project-by-proc proc)))
    (when session
      (let ((process (haskell-session-process session)))
        (haskell-process-reset process)
        (haskell-process-log (format "Event: %S\n" event))
        (haskell-process-log "Process reset.\n")
        (haskell-process-prompt-restart process)))))

(defun haskell-process-filter (proc response)
  "The filter for the process pipe."
  (haskell-process-log (format "<- %S\n" response))
  (let ((session (haskell-process-project-by-proc proc)))
    (when session
      (when (not (eq (haskell-process-cmd (haskell-session-process session))
                     'none))
        (haskell-process-collect session
                                 response
                                 (haskell-session-process session)
                                 'main)))))

(defun haskell-process-log (out)
  "Log to the process log."
  (with-current-buffer (get-buffer-create "*haskell-process-log*")
    (goto-char (point-max))
    (insert out)))

(defun haskell-process-project-by-proc (proc)
  "Find project by process."
  (find-if (lambda (project)
             (string= (haskell-session-name project)
                      (process-name proc)))
           haskell-sessions))

(defun haskell-process-collect (session response process type)
  "Collect input for the response until receives a prompt."
  (haskell-process-set-response process
                                (concat (haskell-process-response process) response))
  (while (haskell-process-live-updates session process))
  (when (string-match haskell-process-prompt-regex
                      (haskell-process-response process))
    (haskell-command-complete
     (haskell-process-cmd process)
     (replace-regexp-in-string
      haskell-process-prompt-regex
      ""
      (haskell-process-response process)))
    (haskell-process-reset process)
    (haskell-process-trigger-queue process)))

(defun haskell-process-reset (process)
  "Reset the process's state, ready for the next send/reply."
  (progn (haskell-process-set-response-cursor process 0)
         (haskell-process-set-response process "")
         (haskell-process-set-cmd process 'none)))

(defun haskell-process-consume (process regex)
  "Consume a regex from the response and move the cursor along if succeed."
  (when (string-match regex
                      (haskell-process-response process)
                      (haskell-process-response-cursor process))
    (haskell-process-set-response-cursor process (match-end 0))
    t))

(defun haskell-process-send-string (process string)
  "Try to send a string to the process's process. Ask to restart if it's not running."
  (let ((child (haskell-process-process process)))
    (if (equal 'run (process-status child))
        (let ((out (concat string "\n")))
          (haskell-process-log (format "-> %S\n" out))
          (process-send-string child out))
      (haskell-process-prompt-restart process))))

(defun haskell-process-prompt-restart (process)
  "Prompt to restart the died process."
  (when (y-or-n-p (format "The Haskell process `%s' has died. Restart? "
                          (haskell-process-name process)))
    (haskell-process-start (haskell-process-session process))))

(defun haskell-process-live-updates (session process)
  "Process live updates."
  (haskell-command-live (haskell-process-cmd process)
                        (haskell-process-response process)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Making commands

(defun haskell-process-queue-command (process command)
  "Add a command to the process command queue."
  (haskell-process-add-to-cmd-queue process command)
  (haskell-process-trigger-queue process))

(defun haskell-process-trigger-queue (process)
  "Trigger the next command in the queue to be ran if there is no current command."
  (if (haskell-process-process process)
      (when (equal (haskell-process-cmd process) 'none)
        (let ((cmd (haskell-process-cmd-queue-pop process)))
          (when cmd
            (haskell-process-set-cmd process cmd)
            (haskell-command-go cmd))))
    (progn (haskell-process-log "Process died or never started. Starting...\n")
           (haskell-process-start (haskell-process-session process)))))

(defun haskell-command-make (state go live complete)
  "Make a process command of the given `type' with the given `go' procedure."
  (list (cons 'state state)
        (cons 'go go)
        (cons 'live live)
        (cons 'complete complete)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Accessing the process

(defun haskell-process-set-process (p v)
  "Set the process's inferior process."
  (haskell-process-set p 'inferior-process v))

(defun haskell-process-process (p)
  "Get the process child."
  (haskell-process-get p 'inferior-process))

(defun haskell-process-name (p)
  "Get the process name."
  (haskell-process-get p 'name))

(defun haskell-process-cmd (p)
  "Get the process's current command."
  (haskell-process-get p 'current-command))

(defun haskell-process-set-cmd (p v)
  "Set the process's current command."
  (haskell-process-set p 'current-command v))

(defun haskell-process-response (p)
  "Get the process's current response."
  (haskell-process-get p 'current-response))

(defun haskell-process-session (p)
  "Get the process's current session."
  (haskell-process-get p 'session))

(defun haskell-process-set-response (p v)
  "Set the process's current response."
  (haskell-process-set p 'current-response v))

(defun haskell-process-set-session (p v)
  "Set the process's current session."
  (haskell-process-set p 'session v))

(defun haskell-process-response-cursor (p)
  "Get the process's current response cursor."
  (haskell-process-get p 'current-response-cursor))

(defun haskell-process-set-response-cursor (p v)
  "Set the process's response cursor."
  (haskell-process-set p 'current-response-cursor v))

(defun haskell-process-add-to-cmd-queue (process cmd)
  "Set the process's response cursor."
  (haskell-process-set process
                       'command-queue
                       (append (haskell-process-cmd-queue process)
                               (list cmd))))

(defun haskell-process-cmd-queue (process)
  "Get the process's command queue."
  (haskell-process-get process 'command-queue))

(defun haskell-process-cmd-queue-pop (process)
  "Get the process's command queue."
  (let ((queue (haskell-process-get process 'command-queue)))
    (unless (null queue)
      (let ((next (car queue)))
        (haskell-process-set process 'command-queue (cdr queue))
        next))))

(defun haskell-process-get (s key)
  "Get the process `key'."
  (let ((x (assoc key s)))
    (when x
      (cdr x))))

(defun haskell-process-set (s key value) 
  "Set the process's `key'."
  (delete-if (lambda (prop) (equal (car prop) key)) s)
  (setf (cdr s) (cons (cons key value)
                      (cdr s)))
  s)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Accessing commands

(defun haskell-command-type (s)
  "Get the command's type."
  (haskell-command-get s 'type))

(defun haskell-command-state (s)
  "Get the command's state."
  (haskell-command-get s 'state))

(defun haskell-command-go (s)
  "Call the command's go function."
  (let ((func (haskell-command-get s 'go)))
    (when func
      (funcall func 
               (haskell-command-state s)))))

(defun haskell-command-complete (s response)
  "Call the command's complete function."
  (let ((func (haskell-command-get s 'complete)))
    (when func
      (funcall func
               (haskell-command-state s)
               response))))

(defun haskell-command-live (s response)
  "Trigger the command's live updates callback."
  (let ((func (haskell-command-get s 'live)))
    (when func
      (funcall func 
               (haskell-command-state s)
               response))))

(defun haskell-command-get (s key)
  "Get the command `key'."
  (let ((x (assoc key s)))
    (when x
      (cdr x))))

(defun haskell-command-set (s key value) 
  "Set the command's `key'."
  (delete-if (lambda (prop) (equal (car prop) key)) s)
  (setf (cdr s) (cons (cons key value)
                      (cdr s)))
  s)
