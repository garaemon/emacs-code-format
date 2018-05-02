;;; code-format.el --- Help to format code

;; Copyright (C) 2016  Ryohei Ueda

;; Author: Ryohei Ueda <garaemona@gmail.com>
;; URL: https://github.com/garaemon/emacs-code-format
;; Version: 1.0
;; Keywords: clang-format, clang, ediff
;; Package-Requires: ()

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This visualizes difference between code of current buffer
;; and formatted code by clang-format in ediff.

;; You need to install clang-format beforehand.
;; http://clang.llvm.org/docs/ClangFormat.html

;;;; Setup

;; (require 'code-format)
;; (global-set-key "\M-[" 'code-format-view)
;; ;; if you want to show diff side-by-side style
;; ;; comment in codes below:
;; ;; (custom-set-variables '(ediff-split-window-function 'split-window-horizontally))
;; ;;

;;; Code:

(defgroup code-format nil
  ""
  :group 'ediff)

(defcustom code-format-clang-format-executable nil
  "Path to clang-format executable."
  :type 'string
  :group 'code-format)

(defcustom code-format-prettier-executable nil
  "Path to prettier executable."
  :type 'string
  :group 'code-format)

(defcustom code-format-clang-options nil
  "Options for clang-format."
  :type 'string
  :group 'code-format)

(defcustom code-format-autopep8-options nil
  "Options for autopep8."
  :type 'string
  :group 'code-format)

(defcustom code-format-yapf-format-executable nil
  "Path to yapf executable."
  :type 'string
  :group 'code-format)

(defcustom code-format-yapf-options nil
  "Options for yapf."
  :type 'string
  :group 'code-format)

(defcustom code-format-prettier-options nil
  "Options for prettier."
  :type 'string
  :group 'code-format)

(defcustom code-format-formatter-alist
  '((c++-mode . code-format-c++-clang-format)
    (python-mode . code-format-python-yapf-format)
    (typescript-mode . code-format-prettier-format)
    (javascript-mode . code-format-prettier-format)
    (web-mode . code-format-prettier-format)
    (js-mode . code-format-prettier-format)
    (js2-mode . code-format-prettier-format))
  "Assosiate list of major mode and code format function."
  :group 'code-format)

(defun code-format-get-clean-formatted-buffer ()
  "Return clean buffer for formatted code."
  (let ((temp-buffer (get-buffer-create "*code-format-buffer*")))
    (with-current-buffer temp-buffer
      (erase-buffer))
    temp-buffer))

;; format function should take three arguments:
;;   1. buffer to format
;;   2. start position
;;   3. end position
;; And format function returns buffer contains formatted code.
(defun code-format-c++-clang-format (code-buffer
                                     char-start char-end)
  "Apply clang-format to specified buffer and region.

Apply clang-format to CODE-BUFFER selected region from
CHAR-START to CHAR-END."
  (with-current-buffer code-buffer      ; current-buffer = code-buffer
    (let ((start (1- (position-bytes char-start)))
          (end (1- (position-bytes char-end)))
          (cursor (1- (position-bytes (point))))
          (temp-buffer (code-format-get-clean-formatted-buffer))
          (exe (or code-format-clang-format-executable
                   (executable-find "clang-format"))))
      (apply #'call-process-region
             (point-min) (point-max) exe
             nil temp-buffer nil
             ;;"-assume-filename" (or (buffer-file-name) "")
             "-offset" (number-to-string start)
             "-length" (number-to-string (- end start))
             "-cursor" (number-to-string cursor)
             code-format-clang-options)
      ;; temp-buffer has '{ "Cursor": 50, "IncompleteFormat": false }'
      ;; at the top.
      (with-current-buffer temp-buffer
        (delete-region (progn
                         (goto-char (point-min))
                         (beginning-of-line)
                         (point))
                       (progn
                         (goto-char (point-min))
                         (forward-line 1)
                         (beginning-of-line)
                         (point))))
      temp-buffer)))

(defun code-format-python-autopep8-format (code-buffer char-start char-end)
  "Format CODE-BUFFER from CHAR-START to CHAR-END with autopep8."
  (with-current-buffer code-buffer      ; current-buffer = code-buffer
    (let ((start (position-bytes char-start))
          (end (position-bytes char-end))
          (temp-buffer (code-format-get-clean-formatted-buffer))
          (exe (or code-format-clang-format-executable
                   (executable-find "autopep8"))))
      (message "%s -- %s" (number-to-string start) (number-to-string end))
      (apply #'call-process-region
             (point-min) (point-max) exe
             nil temp-buffer nil
             ;;"-assume-filename" (or (buffer-file-name) "")
             "--line-range"
             (number-to-string (line-number-at-pos char-start))
             (number-to-string (line-number-at-pos char-end))
             "-"
             code-format-autopep8-options)
      temp-buffer)))

(defun code-format-python-yapf-format (code-buffer char-start char-end)
  "Format CODE-BUFFER from CHAR-START to CHAR-END with yapf."
  (with-current-buffer code-buffer      ; current-buffer = code-buffer
    (let ((start (position-bytes char-start))
          (end (position-bytes char-end))
          (temp-buffer (code-format-get-clean-formatted-buffer))
          (exe (or code-format-yapf-format-executable
                   (executable-find "yapf"))))
      (message "%s -- %s" (number-to-string start) (number-to-string end))
      (apply #'call-process-region
             (point-min) (point-max) exe
             nil temp-buffer nil
             "--lines"
             (format "%d-%d"
                     (line-number-at-pos char-start)
                     (line-number-at-pos char-end))
             code-format-yapf-options)
      temp-buffer)))

(defun code-format-prettier-format (code-buffer char-start char-end)
  "Format CODE-BUFFER from CHAR-START to CHAR-END with prettier."
  (with-current-buffer code-buffer      ; current-buffer = code-buffer
    (let ((start (position-bytes char-start))
          (end (position-bytes char-end))
          (temp-buffer (code-format-get-clean-formatted-buffer))
          (exe (or code-format-prettier-executable
                   (executable-find "prettier"))))
      (apply #'call-process-region
             (point-min) (point-max) exe
             nil temp-buffer nil
             "--range-start" (number-to-string (1- start))
             "--range-end" (number-to-string (1- end))
             "--stdin"
             "--stdin-filepath" (buffer-file-name code-buffer)
             code-format-prettier-options)
      temp-buffer)))

(defun code-format-view-region (char-start char-end)
  "Apply formatter to selected region and merge the result by ediff.

CHAR-START is the begging position of region to format and CHAR-END is
the end position of region to format."
  (interactive
   (if (use-region-p)
       (list (region-beginning) (region-end))
     (list (point) (point))))
  (let ((format-function-symbol
         (cdr (assoc major-mode code-format-formatter-alist))))
    (if format-function-symbol
        (let ((formatted-buffer
               (funcall format-function-symbol (current-buffer)
                        char-start char-end)))
          ;; Set major-mode of `formatted-buffer' to major-mode of `current-buffer' because current
          ;; major-mode of `formatted-buffer' is "Fundamental mode".
          (let ((current-buffer-major-mode major-mode))
            ;; copy `major-mode' value to `current-buffer-major-mode' because in
            ;; `with-current-buffer' macro, `major-mode' value is over written to the value of
            ;; `formatted-buffer'.
            (with-current-buffer formatted-buffer
              (funcall current-buffer-major-mode)
              ))
          (if (code-format-have-difference (current-buffer) formatted-buffer)
              (ediff-buffers (current-buffer) formatted-buffer)
            (message "No need to fix! Have a good luck!")))
      (message "No formatter is specified for %s" major-mode))))

(defun code-format-have-difference (buffer-a buffer-b)
  "Return true if two buffers has difference.

BUFFER-A -- a buffer.
BUFFER-B -- a buffer."
  (not (string= (with-current-buffer buffer-a
                  (buffer-string))
                (with-current-buffer buffer-b
                  (buffer-string)))))

(defun code-format-view ()
  "Apply clang-format to current buffer and merge the result by ediff."
  (interactive)
  (message "use-region-p: %s" (use-region-p))
  (if (not (use-region-p))
      (code-format-view-region (point-min) (point-max))
    (code-format-view-region (region-beginning) (region-end))))

(global-set-key "\M-[" 'code-format-view)

(defvar code-format-ediff-last-windows nil)

(defun code-format-store-pre-ediff-winconfig ()
  "Save window configuration before running ediff."
  (setq code-format-ediff-last-windows (current-window-configuration)))

(defun code-format-restore-pre-ediff-winconfig ()
  "Set window configuration as stored before running ediff."
  (set-window-configuration code-format-ediff-last-windows))

(add-hook 'ediff-before-setup-hook #'code-format-store-pre-ediff-winconfig)
(add-hook 'ediff-quit-hook #'code-format-restore-pre-ediff-winconfig)

(provide 'code-format)
;;; code-format.el ends here
