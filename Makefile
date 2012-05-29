# Makefile for Emacs configs

# Install config files
install: emacs_backup .gnus .emacs.d .emacs

# Backup current config files
backup:
	mkdir -p emacs_backup
	cp -R "${HOME}/.emacs.d" emacs_backup
	cp -R "${HOME}/.emacs" emacs_backup
	cp -R "${HOME}/.gnus" emacs_backup

.gnus:
	cp -R gnus-rc.el "${HOME}/.gnus"

.emacs.d:
	mkdir -p "${HOME}/.emacs.d"
	cp -R emacs.d/* "${HOME}/.emacs.d"

.emacs:
	cp emacs-rc.el "${HOME}/.emacs"
