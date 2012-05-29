;; email stuff

; -*- Lisp -*-

; Use TLS1 for SSL
(setq imap-ssl-program "openssl s_client -tls1 -connect %s:%p")

; Read my mail from IMAP (I don't use Gnus for news ;P)
(setq gnus-select-method '(nnimap "liv.ac.uk"
                                  (nnimap-address "imap.liv.ac.uk")
                                  (nnimap-server-port 993)
                                  (nnimap-stream ssl)))

;(add-hook 'gnus-group-mode-hook 'gnus-topic-mode)

; Use threaded e-mail
(setq gnus-summary-thread-gathering-function 
      'gnus-gather-threads-by-subject)

;; Also, I prefer to see only the top level message.  If a message has
;; several replies or is part of a thread, only show the first
;; message.  'gnus-thread-ignore-subject' will ignore the subject and
;; look at 'In-Reply-To:' and 'References:' headers.
(setq gnus-thread-hide-subtree t)
(setq gnus-thread-ignore-subject t)
