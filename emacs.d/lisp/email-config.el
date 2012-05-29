(setq gnus-secondary-select-methods '((nnml "")))

;; use gnus to send mail
(setq mail-user-agent 'message-user-agent)

;; set up gnus for sending mail
(setq message-send-mail-function 'smtpmail-send-it
      smtpmail-starttls-credentials '(("mail1.liv.ac.uk" 25 nil nil))
      smtpmail-auth-credentials '(("mail1.liv.ac.uk" 25 "rjberry" nil))
      smtpmail-default-smtp-server "mail1.liv.ac.uk"
      smtpmail-smtp-server "mail1.liv.ac.uk"
      smtpmail-smtp-service 25
      smtpmail-local-domain "liverpool.ac.uk")
