(require 'font-lock)

(defconst roxen-locale-doc-font-lock-keywords nil 
    "The font lock keywords for the locale documentation mode")

(defun roxendoc-font-lock-hack-file-coding-system-perhaps ( foo )
  (interactive)
  (condition-case fel
      (if (fboundp 'set-buffer-file-coding-system)
	  (let ((coding (buffer-substring 
			 (match-beginning 2) (match-end 2))))
	    (set-buffer-file-coding-system (car (read-from-string coding)))
	    (message "charset >%s<"  coding)))
    (t (message "Warning: unsupported charset >%s<" 
		(buffer-substring (match-beginning 2) (match-end 2))) nil))
  nil
)

(setq roxen-locale-doc-font-lock-keywords
 (list 
  '("^\\(--- charset\\)[ \t]*\\(.*\\)$" 
    (1 font-lock-reference-face) 
    (2 font-lock-keyword-face)
    (roxendoc-font-lock-hack-file-coding-system-perhaps))
    '( "^\\(--- module\\) \\(.*\\)$"   
       (1 font-lock-reference-face) 
       (2 font-lock-variable-name-face) )
    '( "^\\(--- variable\\) \\(.*\\)$" 
       (1 font-lock-reference-face) 
       (2 font-lock-variable-name-face) )
    '( "^-[^-].*$"  0 font-lock-comment-face)
    '( "^--[^-].*$"  0 font-lock-function-name-face)
))


(defun roxendoc-indent-line ()
  "Indent current line as far as it should go according
to the syntax/context"
  (interactive)
  ; nop for now..
  )

(defun roxen-locale-doc-mode ()
  (interactive)
  (kill-all-local-variables)
  (setq major-mode 'roxen-locale-doc-mode)
  (make-local-variable 'indent-line-function)
  (setq indent-line-function 'roxendoc-indent-line)
  (setq mode-name "RoxenDoc")
  (make-local-variable 'comment-start)
  (setq comment-start "# ")
  (make-local-variable 'comment-end)
  (setq comment-end "")
  (make-local-variable 'comment-column)
  (setq comment-column 0)
  (make-local-variable 'comment-start-skip)
  (setq comment-start-skip "[#-]+ *")
  (make-local-variable 'font-lock-keywords)
  (setq font-lock-keywords roxen-locale-doc-font-lock-keywords)
  (run-hooks 'roxen-locale-doc-mode-hook))


(put 'roxen-locale-doc-mode 'font-lock-defaults 
     '((roxen-locale-doc-font-lock-keywords
	roxen-locale-doc-font-lock-keywords
	roxen-locale-doc-font-lock-keywords
	roxen-locale-doc-font-lock-keywords)
       t nil nil nil))

