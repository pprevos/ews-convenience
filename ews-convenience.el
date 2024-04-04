;;; ews.el --- Emacs Writing Studio: Convenience functions for authors  -*- lexical-binding: t; -*-

;; Copyright (C) 2024 Peter Prevos

;; Author: Peter Prevos <peter@prevos.net>
;; Maintainer: Peter Prevos <peter@prevos.net>
;; Created: 1 January 2024
;; Version: 1.1.2
;; Keywords: convenience
;; Homepage: https://lucidmanager.org/tags/emacs/
;; URL: https://github.com/pprevos/emacs-writing-studio
;; Package-Requires: ((emacs "29.1") (olivetti "2.0.5") (biblio "0.3") (citar "1.4.0"))

;; This file is NOT part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <https://www.gnu.org/licenses/>.
;;
;;; Commentary:
;;
;; Series of convenience functions for Emacs Writing Studio
;; https://lucidmanager.org/tags/emacs
;;
;;; Code:

(require 'cl-lib)
(require 'olivetti)
(require 'biblio)
(require 'citar)
(require 'org)

;; Emacs Writing Studio Customisation
(defgroup ews ()
  "Emacs Writing Studio."
  :group 'files
  :link '(url-link :tag "Homepage" "https://lucidmanager.org/tags/emacs/"))

(defcustom ews-documents-directory
  (concat (file-name-as-directory (getenv "HOME")) "Documents")
  "Location of documents."
  :group 'ews
  :type 'directory)

(defcustom ews-bibliography-directory
  (concat (file-name-as-directory ews-documents-directory) "library")
  "Location of BibTeX bibliographies and attachments."
  :group 'ews
  :type 'directory)

(defcustom ews-notes-directory
  (concat (file-name-as-directory ews-documents-directory) "notes")
  "Location of notes."
  :group 'ews
  :type 'directory)

(defcustom ews-music-directory
  (concat (file-name-as-directory (getenv "HOME")) "Music")
  "Location of music files."
  :group 'ews
  :type 'directory)

(defcustom ews-inbox-file
  (concat (file-name-as-directory ews-documents-directory) "inbox.org")
  "Location of notes."
  :group 'ews
  :type 'file)

(defcustom ews-elfeed-config-file
  (concat (file-name-as-directory ews-documents-directory) "elfeed.org")
  "Location of RSS feed configuration."
  :group 'ews
  :type 'file)

(defcustom ews-todo-file
  (concat (file-name-as-directory ews-documents-directory) "todo.org")
  "Location of todo lists."
  :group 'ews
  :type 'file)

(defvar ews--load-directory
  (file-name-directory load-file-name)
  "Path of the ews package.")

;; Check for missing external software
;;;###autoload
(defun ews-missing-executables (prog-list)
  "Identified missing executables in PROG-LIST.

Sublists indicate that one of the entries is required."
  (let ((missing '()))
    (dolist (exec prog-list)
      (if (listp exec)
          (unless (cl-some #'executable-find exec)
            (push (format "(%s)" (mapconcat 'identity exec " or ")) missing))
        (unless (executable-find exec)
          (push exec missing))))
    (if missing
        (message "Missing executable files(s): %s"
                 (mapconcat 'identity missing ", ")))))

;; Distraction-free writing
;;;###autoload
(defun ews-distraction-free ()
  "Distraction-free writing environment using Olivetti package."
  (interactive)
  (if (equal olivetti-mode nil)
      (progn
        (window-configuration-to-register 1)
        (delete-other-windows)
        (text-scale-set 2)
        (olivetti-mode t))
    (progn
      (if (eq (length (window-list)) 1)
          (jump-to-register 1))
      (olivetti-mode 0)
      (text-scale-set 0))))

(defun ews--biblio-lookup ()
  "Combines biblio-lookup and biblio-doi-insert-bibtex."
  (interactive)
  (let* ((dbs (biblio--named-backends))
         (db-list (append dbs '(("DOI" . biblio-doi-backend))))
         (db-selected (biblio-completing-read-alist
                       "Database:"
                       db-list)))
    (if (eq db-selected 'biblio-doi-backend)
        (let ((doi (read-string "DOI: ")))
          (biblio-doi-insert-bibtex doi))
      (biblio-lookup db-selected))))

;;;###autoload
(defun ews-biblio-bibtex-lookup ()
  "Use curent buffer or Select BibTeX file, lookup with Biblio and insert entry."
  (interactive)
  (let ((current-mode major-mode)
	(bibfile (if (equal major-mode 'bibtex-mode)
		     (buffer-file-name)
		   (completing-read
                    "BibTeX file:"
                    (citar--bibliography-files)))))
    (find-file bibfile)
    (goto-char (point-max))
    (ews--biblio-lookup)
    (save-buffer)))

;;;###autoload
(defun ews-org-insert-notes-drawer ()
  "Generate or open a NOTES drawer under the current heading."
  (interactive)
  (push-mark)
  (org-previous-visible-heading 1)
  (forward-line)
  (if (looking-at-p "^[ \t]*:NOTES:")
      (progn
        (org-fold-hide-drawer-toggle 'off)
        (re-search-forward "^[ \t]*:END:" nil t)
        (forward-line -1)
        (org-end-of-line)
        (org-return))
    (org-insert-drawer nil "NOTES"))
  (org-unlogged-message "Press <C-u C-SPACE> to return to the previous position."))

;;;###autoload
(defun ews-org-count-words ()
  "Add word count to each heading property drawer in an Org mode buffer."
  (interactive)
  (org-map-entries
   (lambda ()
     (let* ((start (point))
            (end (save-excursion (org-end-of-subtree)))
            (word-count (count-words start end)))
       (org-set-property "wordcount" (number-to-string word-count))
       (unless (org-entry-get nil "target")
         (org-set-property "target" "0"))))))

;;;###autoload
(defun ews-org-screenshot ()
  "Take a screenshot with ImageMagick and insert as an Org mode link."
  (interactive)
  (let ((filename (read-file-name "Enter filename for screenshot: " default-directory)))
    (unless (string-equal "png" (file-name-extension filename))
      (setq filename (concat (file-name-sans-extension filename) ".png")))
    (call-process-shell-command (format "import %s" filename))
    (insert (format "#+caption: %s\n" (read-from-minibuffer "Caption: ")))
    (insert (format "[[file:%s]]" filename))
    (org-redisplay-inline-images)))


(provide 'ews)
;;; ews.el ends here

