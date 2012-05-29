; Perl config


;; perl stuff

(defalias 'perl-mode 'cperl-mode)

;; 4-space indents
(setq cperl-close-paren-offset -4)
(setq cperl-continued-statement-offset 4)
(setq cperl-indent-level 4)
(setq cperl-indent-parens-as-block t)
(setq cperl-tab-always-indent t)

;; functions for quickly switching between Perl package files and tests
(defun rjb-cperl-switch-lib-t ()
  (interactive)
  (let ((file (buffer-file-name)))
    (if (null file)
        (error "Not visiting a file.")
      (if (string-match "\\.pm$" file)
          (rjb-cperl-find-test-file file)
          (rjb-cperl-find-package-file file)))))

(defun rjb-cperl-find-test-file (file)
  (if (string-match "^\\(.*\\)/lib/\\(.*\\)\\.pm$" file)
      (find-file (concat (match-string 1 file) "/t/" (match-string 2 file) ".t"))
    (error "Not inside a Perl lib folder.")))

(defun rjb-cperl-find-package-file (file)
  (if (string-match "\\(.*\\)/t/\\(.*\\)\\.t$" file)
      (find-file (concat (match-string 1 file) "/lib/" (match-string 2 file)
                         ".pm"))
    (error "Not inside a Perl test folder.")))

(defun rjb-cperl-package-root (file)
  (if (string-match "^\\(.*\\)/\\(?:t\\|lib\\)/.*$" file)
      (match-string 1 file)
    (error "Not inside a Perl package.")))

;; following for my yasnippet test-stub
(defun rjb-cperl-test-path-to-package (test-path)
  (replace-regexp-in-string "\\.t$" "" (replace-regexp-in-string "/" "::" test-path)))

(defun rjb-cperl-test-package-name (file)
  (if (string-match "^.*/t/\\(.*\\)$" file)
      (rjb-cperl-test-path-to-package (match-string 1 file))
    (error "Not in a package test.")))

; finish this at some point
;(defun rjb-cperl-package-run-tests ()
;  (interactive)
;  (let ((package-root (rjb-cperl-package-root (buffer-file-name)))
;        (output-buffer ()))
;    (start-process "cperl-prove" output-buffer
;                   "prove" "-l" "-r" (shell-quote-argument (concat package-root)

(define-key cperl-mode-map (kbd "C-c C-c C-c") 'rjb-cperl-switch-lib-t)