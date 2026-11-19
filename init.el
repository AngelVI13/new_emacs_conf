;;; init.el --- Emacs configuration -*- lexical-binding: t; -*-

;;;; Startup / performance
(add-hook 'emacs-startup-hook
          (lambda () (setq gc-cons-threshold (* 64 1024 1024))))
(setq read-process-output-max (* 1024 1024)) ; faster LSP communication

;;;; PATH: the daemon starts from systemd, so add dirs set only in ~/.bashrc
(dolist (dir '("~/.local/bin" "~/.cargo/bin" "~/.opam/default/bin"
               "~/go/bin" "~/Downloads/go/bin"))
  (let ((dir (expand-file-name dir)))
    (when (and (file-directory-p dir) (not (member dir exec-path)))
      (add-to-list 'exec-path dir t)
      (setenv "PATH" (concat (getenv "PATH") path-separator dir)))))

(setq custom-file (locate-user-emacs-file "custom.el"))
(load custom-file 'noerror 'nomessage)

;;;; Packages
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
;; No refresh at startup: use-package refreshes only when a package is missing.
;; Update manually with M-x package-upgrade-all.
(require 'use-package)
(setq use-package-always-ensure t)

;;;; General editing
(setq ring-bell-function 'ignore
      make-backup-files nil
      create-lockfiles nil
      auto-save-file-name-transforms
      `((".*" ,(locate-user-emacs-file "auto-save/") t)))
(make-directory (locate-user-emacs-file "auto-save/") t)

(setq-default tab-width 4
              indent-tabs-mode nil
              truncate-lines t        ; nowrap
              fill-column 100)

(global-font-lock-mode 1)
(show-paren-mode 1)
(blink-cursor-mode -1)
(savehist-mode 1)
(which-key-mode 1)                    ; shows available keys after SPC

;; Relative line numbers (not in terminals)
(setq display-line-numbers-type 'relative)
(global-display-line-numbers-mode 1)

;; Color column at 100 chars in code
(add-hook 'prog-mode-hook #'display-fill-column-indicator-mode)

;; Ligatures (native, via HarfBuzz composition) for Iosevka in code buffers
(defconst my/ligatures
  '("<---" "<--" "<<-" "<-" "->" "->>" "-->" "--->" "<->" "<-->" "<--->"
    "<==" "<===" "<=" "=>" "=>>" "==>" "===>" ">=" "<=>" "<==>" "<===>"
    "<!--" "<~~" "<~" "~>" "~~>" "::" ":::" "==" "!=" "===" "!==" ":="
    "<|" "<|>" "|>" "<>" "</" "/>" "</>" "++" "+++" "&&" "||" "|||"
    ">>" "<<" ">>=" "<<=" "/=" "//" "///" ".." "..." "..<" "**" "***"
    "|]" "[|" "^=" "-<" ">-" "-<<" ">>-" "=<<"))

(defvar my/ligature-table
  (let ((table (make-char-table nil))
        (groups (seq-group-by #'string-to-char my/ligatures)))
    (set-char-table-parent table composition-function-table)
    (dolist (group groups table)
      (set-char-table-range
       table (car group)
       `([,(regexp-opt (cdr group)) 0 font-shape-gstring])))))

(defun my/enable-ligatures ()
  (setq-local composition-function-table my/ligature-table))
(add-hook 'prog-mode-hook #'my/enable-ligatures)

;; Soft wrap in notes
(add-hook 'text-mode-hook #'visual-line-mode)

;;;; Theme
(use-package gruber-darker-theme
  :init
  ;; The theme file lacks a lexical-binding cookie; silence that warning only
  (require 'warnings)
  (when-let* ((file (locate-library "gruber-darker-theme.el")))
    (add-to-list 'warning-suppress-log-types
                 `(files missing-lexbind-cookie ,(abbreviate-file-name file))))
  :config
  (load-theme 'gruber-darker t))

;;;; Tree-sitter (grammars are compiled on first use)
(setopt treesit-enabled-modes t
        treesit-auto-install-grammar 'always)
(autoload 'markdown-ts-mode "markdown-ts-mode" nil t)
(autoload 'markdown-ts-view-mode "markdown-ts-mode" nil t)
(add-to-list 'auto-mode-alist '("\\.md\\'" . markdown-ts-mode))
(setq go-ts-mode-indent-offset 4)
(add-hook 'go-ts-mode-hook (lambda () (setq-local indent-tabs-mode t)))

;;;; Completion
(fido-vertical-mode 1)                ; minibuffer: files, buffers, commands
(setq completions-format 'one-column
      completions-max-height 15
      completion-show-help nil
      completion-auto-select 'second-tab)

;; In-buffer popup that opens as you type (like nvim-cmp)
(use-package corfu
  :init
  (setq corfu-auto t
        corfu-auto-prefix 3           ; after 3 characters...
        corfu-auto-trigger "."        ; ...or right after a dot
        corfu-auto-delay 0.1
        corfu-preselect 'first        ; RET accepts the first candidate
        corfu-preview-current nil     ; never insert a candidate implicitly
        corfu-cycle t
        corfu-popupinfo-delay '(0.5 . 0.2))
  :config
  ;; Evil's insert keys for jk and backspace should also trigger completion
  (with-eval-after-load 'corfu-auto
    (add-to-list 'corfu-auto-commands 'my/evil-insert-jk)
    (add-to-list 'corfu-auto-commands 'evil-delete-backward-char-and-join))
  (global-corfu-mode 1)
  (corfu-popupinfo-mode 1)            ; documentation popup next to the list
  (with-eval-after-load 'evil
    (evil-define-key 'insert corfu-map
      (kbd "C-e") #'corfu-quit
      (kbd "C-f") #'corfu-popupinfo-scroll-up
      (kbd "C-b") #'corfu-popupinfo-scroll-down)))

;; Buffer words as a fallback source (like cmp-buffer)
(defun my/add-dabbrev-capf ()
  (add-hook 'completion-at-point-functions #'dabbrev-capf 90 t))
(add-hook 'prog-mode-hook #'my/add-dabbrev-capf)
(add-hook 'text-mode-hook #'my/add-dabbrev-capf)

(use-package yasnippet                ; lets Eglot expand LSP snippets
  :config
  (yas-global-mode 1))

;;;; Search / projects
(setq xref-search-program 'ripgrep
      grep-command "rg -nH --no-heading "
      dired-listing-switches "-alh --group-directories-first"
      dired-kill-when-opening-new-dired-buffer t)

;; Known projects: remembered when a file/dir inside them is opened,
;; switched with SPC p p (straight into find-file)
(setq project-switch-commands #'project-find-file
      project-list-exclude '("/\\.emacs\\.d/elpa/" "\\`/tmp/"))

(defun my/remember-project ()
  (when-let* ((pr (project-current)))
    (project-remember-project pr)))
(add-hook 'find-file-hook #'my/remember-project)
(add-hook 'dired-mode-hook #'my/remember-project)

;; Live search with preview (works with fido-vertical-mode)
(use-package consult
  :config
  ;; Whole input goes to rg; trailing -flags are passed through (hello -tpy)
  (setq consult-async-split-style nil)

  ;; Allow "quoted phrases": "hello world" -tpy -> hello\ world -tpy
  (defun my/consult-unquote-input (split)
    (cons (replace-regexp-in-string
           "\"\\([^\"]*\\)\""
           (lambda (m) (string-replace " " "\\ " (match-string 1 m)))
           (car split) t t)
          (cdr split)))
  (advice-add 'consult--command-split :filter-return #'my/consult-unquote-input)

  ;; No live preview: only RET opens the selected candidate
  (setq consult-preview-key nil)

  ;; C-c C-e in consult-ripgrep: save the results to a grep buffer
  ;; (navigate with RET, SPC o reopens it, g re-runs the search)
  (defvar my/consult-grep-active nil)
  (advice-add 'consult-ripgrep :around
              (lambda (fn &rest args)
                (let ((my/consult-grep-active t)) (apply fn args))))

  (defun my/consult-grep-export ()
    "Run the current `consult-ripgrep' search in a `grep-mode' buffer."
    (interactive)
    (unless my/consult-grep-active
      (user-error "Export is only available in consult-ripgrep"))
    (let* ((input (minibuffer-contents-no-properties))
           (dir default-directory)
           (cmd (remove "--null"
                        (car (funcall (consult--ripgrep-make-builder '(".")) input)))))
      (run-at-time 0 nil
                   (lambda ()
                     (require 'grep)
                     (let ((default-directory dir))
                       (compilation-start (mapconcat #'shell-quote-argument cmd " ")
                                          #'grep-mode
                                          (lambda (_) (format "*grep: %s*" input))))))
      (abort-recursive-edit)))
  (define-key minibuffer-local-map (kbd "C-q") #'my/consult-grep-export))

;;;; Spell checking
(when (executable-find "aspell")
  (setq ispell-program-name "aspell"
        ispell-dictionary "en_US"
        ispell-extra-args '("--sug-mode=ultra")
        flyspell-issue-message-flag nil)
  (add-hook 'prog-mode-hook #'flyspell-prog-mode)
  (add-hook 'text-mode-hook #'flyspell-mode))

;;;; TODO highlighting (native replacement for todo-comments)
(defconst my/todo-keywords
  '(("FIX\\|FIXME\\|BUG\\|FIXIT\\|ISSUE" . error)
    ("TODO" . font-lock-function-name-face)
    ("HACK\\|WARN\\|WARNING\\|XXX" . warning)
    ("PERF\\|OPTIM\\|PERFORMANCE\\|OPTIMIZE" . font-lock-keyword-face)
    ("NOTE\\|INFO" . success)
    ("TEST\\|TESTING\\|PASSED\\|FAILED" . font-lock-constant-face)))

(defun my/highlight-todos ()
  (font-lock-add-keywords
   nil
   (mapcar (lambda (kw)
             `(,(concat "\\<\\(" (car kw) "\\):") 1 '(:inherit ,(cdr kw) :weight bold) prepend))
           my/todo-keywords)))
(add-hook 'prog-mode-hook #'my/highlight-todos)

(defun my/project-todos ()
  "List TODO-style comments in the current project."
  (interactive)
  (project-find-regexp
   (concat "\\<\\(" (mapconcat #'car my/todo-keywords "\\|") "\\):")))

;;;; LSP (Eglot, built-in)
(use-package eglot
  :ensure nil
  :hook ((python-mode python-ts-mode go-ts-mode go-mod-ts-mode) . eglot-ensure)
  :config
  (setq eglot-autoshutdown t
        eglot-extend-to-xref t
        eglot-events-buffer-config '(:size 0 :format full))
  ;; ty + ruff together through rass, using the project's uv environment
  (add-to-list 'eglot-server-programs
               '((python-mode python-ts-mode) . ("uv" "run" "rass" "python")))
  (setq-default
   eglot-workspace-configuration
   '(:gopls (:analyses (:nilness t :unusedparams t :unusedwrite t :useany t
                        :shadow t :unusedvariable t)
             :experimentalPostfixCompletions t
             :gofumpt t
             :staticcheck t)
     ;; ocamllsp
     :codelens (:enable t)
     :inlayHints (:enable t)
     :syntaxDocumentation (:enable t)
     :duneDiagnostics (:enable t)
     :extendedHover (:enable t)
     :merlinJumpCodeActions (:enable t))))

;; Pipe LSP traffic through emacs-lsp-booster
(use-package eglot-booster
  :vc (:url "https://github.com/jdtsmith/eglot-booster")
  :after eglot
  :config
  (setq eglot-booster-io-only t)      ; Emacs 30+ parses JSON fast natively
  (eglot-booster-mode 1))

(setq eldoc-idle-delay 0.25
      ;; Skip the echo area when the *eldoc* buffer is visible in a window
      eldoc-echo-area-prefer-doc-buffer t
      flymake-show-diagnostics-at-end-of-line t) ; like virtual_text

;; Signature help and hover often repeat the same type. Show signature help
;; only while typing (insert state) and hover only outside of it.
(defun my/eldoc-signature (cb &rest args)
  (when (evil-insert-state-p)
    (apply #'eglot-signature-eldoc-function cb args)))

(defun my/eldoc-hover (cb &rest args)
  (unless (evil-insert-state-p)
    (apply #'eglot-hover-eldoc-function cb args)))

(defun my/eglot-split-eldoc ()
  (if (eglot-managed-p)
      (setq-local eldoc-documentation-functions
                  (cl-substitute #'my/eldoc-hover #'eglot-hover-eldoc-function
                                 (cl-substitute #'my/eldoc-signature
                                                #'eglot-signature-eldoc-function
                                                eldoc-documentation-functions)))
    (remove-hook 'eldoc-documentation-functions #'my/eldoc-signature t)
    (remove-hook 'eldoc-documentation-functions #'my/eldoc-hover t)))
(add-hook 'eglot-managed-mode-hook #'my/eglot-split-eldoc)

(defun my/show-line-diagnostics ()
  "Show diagnostics on the current line."
  (interactive)
  (if-let* ((diags (flymake-diagnostics (line-beginning-position) (line-end-position))))
      (message "%s" (mapconcat #'flymake-diagnostic-text diags "\n"))
    (message "No diagnostics on this line")))

(defun my/format-buffer ()
  "Format with the LSP server; in Python also organize imports (ruff)."
  (interactive)
  (eglot-format-buffer)
  (when (derived-mode-p 'python-base-mode)
    (eglot-code-action-organize-imports (point-min) (point-max))))

;;;; Format on save
(defvar my/format-on-save t
  "When non-nil, format Go/OCaml/web files on save.")

(defun my/toggle-format-on-save ()
  (interactive)
  (setq my/format-on-save (not my/format-on-save))
  (message "Format on save: %s" (if my/format-on-save "on" "off")))

(defun my/eglot-format-before-save ()
  (when (and my/format-on-save (eglot-managed-p))
    (condition-case err
        (eglot-format-buffer)
      (error (message "Format failed: %s" (error-message-string err))))))

(defun my/external-format (program &rest args)
  "Run PROGRAM with ARGS on the saved file, then reload the buffer."
  (when (and my/format-on-save (executable-find program))
    (if (zerop (apply #'call-process program nil "*format-errors*" nil args))
        (revert-buffer :ignore-auto :noconfirm :preserve-modes)
      (message "%s failed, see *format-errors*" program))))

(defun my/go-after-save ()
  (my/external-format "golines" "-m" "90" "-w" buffer-file-name))

(defun my/prettier-after-save ()
  (when (and buffer-file-name
             (string-match-p "\\.\\(html\\|css\\|js\\)\\'" buffer-file-name)
             (not (string-match-p "\\.eml\\.html\\'" buffer-file-name)))
    (my/external-format "prettier" "-w" buffer-file-name)))

(add-hook 'go-ts-mode-hook
          (lambda ()
            (add-hook 'before-save-hook #'my/eglot-format-before-save nil t)
            (add-hook 'after-save-hook #'my/go-after-save nil t)))
(add-hook 'after-save-hook #'my/prettier-after-save)

;;;; OCaml
(use-package tuareg
  :hook (tuareg-mode . (lambda ()
                         (add-hook 'before-save-hook #'my/eglot-format-before-save nil t))))

(use-package ocaml-eglot              ; extra ocamllsp features on top of Eglot
  :after tuareg
  :hook ((tuareg-mode . ocaml-eglot)
         (tuareg-mode . eglot-ensure)))

(use-package dune)

(use-package utop
  :hook (tuareg-mode . utop-minor-mode))

;;;; Markdown / Org
(defun my/markdown-toggle-preview ()
  "Toggle between editing and rendered view of a Markdown file."
  (interactive)
  (cond ((derived-mode-p 'markdown-ts-view-mode) (markdown-ts-mode))
        ((derived-mode-p 'markdown-ts-mode) (markdown-ts-view-mode))
        (t (user-error "Not a Markdown buffer"))))

(setq org-directory "~/Documents/notes"
      org-default-notes-file (expand-file-name "inbox.org" org-directory)
      org-agenda-files (list org-directory)
      org-startup-indented t)

;;;; Terminal
(use-package vterm
  :commands vterm
  :init
  (setq vterm-always-compile-module t)
  :hook (vterm-mode . (lambda () (display-line-numbers-mode -1))))

;;;; Harpoon (native replacement: 5 file slots saved across sessions)
(defvar my/harpoon-files nil "Files marked with `my/harpoon-add'.")
(add-to-list 'savehist-additional-variables 'my/harpoon-files)

(defun my/harpoon-add ()
  (interactive)
  (let ((file (or buffer-file-name (user-error "Buffer is not visiting a file"))))
    (cond ((member file my/harpoon-files) (message "Already marked"))
          ((>= (length my/harpoon-files) 5) (user-error "All 5 slots used, edit with SPC h"))
          (t (setq my/harpoon-files (append my/harpoon-files (list file)))
             (message "Harpoon %d: %s" (length my/harpoon-files) (abbreviate-file-name file))))))

(defun my/harpoon-jump (n)
  (if-let* ((file (nth (1- n) my/harpoon-files)))
      (find-file file)
    (message "Harpoon slot %d is empty" n)))

(define-derived-mode my/harpoon-menu-mode text-mode "Harpoon"
  "Edit the list of harpooned files; one file per line.")

(defun my/harpoon-menu ()
  "Edit harpoon slots. RET opens the file at point, q saves and closes."
  (interactive)
  (pop-to-buffer (get-buffer-create "*harpoon*")
                 '((display-buffer-at-bottom) (window-height . 8)))
  (erase-buffer)
  (insert (mapconcat #'abbreviate-file-name my/harpoon-files "\n"))
  (goto-char (point-min))
  (my/harpoon-menu-mode))

(defun my/harpoon-menu-save ()
  (interactive)
  (setq my/harpoon-files
        (mapcar #'expand-file-name
                (split-string (buffer-string) "\n" t "[ \t]+"))))

(defun my/harpoon-menu-quit ()
  (interactive)
  (my/harpoon-menu-save)
  (quit-window t))

(defun my/harpoon-menu-select ()
  (interactive)
  (my/harpoon-menu-save)
  (let ((file (string-trim (thing-at-point 'line t))))
    (quit-window t)
    (unless (string-empty-p file)
      (find-file (expand-file-name file)))))

;;;; Misc helpers
(defun my/doc-pane (width)
  "Toggle a WIDTH column *eldoc* documentation pane on the left."
  (let* ((buf (if (buffer-live-p eldoc--doc-buffer)
                  eldoc--doc-buffer
                (setq eldoc--doc-buffer (get-buffer-create " *eldoc*"))))
         (win (get-buffer-window buf)))
    (if win
        (delete-window win)
      (let ((new (split-window nil (- width) 'left)))
        (set-window-buffer new buf)
        (set-window-dedicated-p new t) ; keep other buffers out of it
        (window-preserve-size new t t)))))

;; No line numbers in the eldoc buffer (it re-enters special-mode on every update)
(advice-add 'display-line-numbers--turn-on :before-until
            (lambda () (string-match-p "\\` ?\\*eldoc" (buffer-name))))

(defun my/open-results ()
  "Show the last grep/xref/compilation results list."
  (interactive)
  (if (buffer-live-p next-error-last-buffer)
      (display-buffer next-error-last-buffer
                      '((display-buffer-at-bottom) (window-height . 10)))
    (user-error "No results list yet")))

(defun my/find-file ()
  (interactive)
  (if (project-current) (project-find-file) (call-interactively #'find-file)))

(defun my/new-terminal ()
  (interactive)
  (vterm t))

;;;; Evil (Vim keybindings)
(use-package evil
  :init
  (setq evil-want-C-u-scroll t
        evil-want-keybinding nil      ; required by evil-collection
        evil-undo-system 'undo-redo
        ;; Block cursor in every state
        evil-normal-state-cursor 'box
        evil-insert-state-cursor 'box
        evil-visual-state-cursor 'box
        evil-replace-state-cursor 'box
        evil-operator-state-cursor 'box
        evil-motion-state-cursor 'box
        evil-emacs-state-cursor 'box)
  :config
  (evil-mode 1)
  (evil-set-leader '(normal visual motion) (kbd "SPC"))

  ;; jk leaves insert mode (also in vterm)
  (defun my/evil-insert-jk ()
    (interactive)
    (if (derived-mode-p 'vterm-mode)
        (let ((evt (read-event nil nil 0.2)))
          (cond ((eq evt ?k) (evil-normal-state))
                (t (vterm-send-string "j")
                   (when evt (push evt unread-command-events)))))
      (self-insert-command 1 ?j)
      (let ((evt (read-event nil nil 0.2)))
        (cond ((eq evt ?k) (delete-char -1) (evil-normal-state))
              (evt (push evt unread-command-events))))))
  (define-key evil-insert-state-map (kbd "j") #'my/evil-insert-jk)
  (define-key evil-insert-state-map (kbd "C-SPC") #'completion-at-point)

  ;; Refresh docs when switching between insert and normal state
  (eldoc-add-command 'my/evil-insert-jk 'evil-normal-state 'evil-force-normal-state
                     'evil-insert 'evil-append 'evil-insert-line 'evil-append-line
                     'evil-open-below 'evil-open-above 'evil-change 'evil-substitute)

  ;; Center the screen after jumps (C-] C-o C-i)
  (defun my/recenter (&rest _) (recenter))
  (dolist (fn '(evil-jump-backward evil-jump-forward evil-jump-to-tag))
    (advice-add fn :after #'my/recenter))

  ;; Leader keys
  (evil-define-key '(normal visual motion) 'global
    (kbd "<leader>e")  #'my/show-line-diagnostics
    (kbd "<leader>E")  #'flymake-show-project-diagnostics
    (kbd "<leader>[")  #'flymake-goto-prev-error
    (kbd "<leader>]")  #'flymake-goto-next-error
    (kbd "<leader>q")  #'flymake-show-buffer-diagnostics
    (kbd "<leader>t")  #'my/new-terminal
    (kbd "<leader>T")  #'my/project-todos
    (kbd "<leader>H")  #'my/harpoon-add
    (kbd "<leader>h")  #'my/harpoon-menu
    (kbd "<leader>1")  (lambda () (interactive) (my/harpoon-jump 1))
    (kbd "<leader>2")  (lambda () (interactive) (my/harpoon-jump 2))
    (kbd "<leader>3")  (lambda () (interactive) (my/harpoon-jump 3))
    (kbd "<leader>4")  (lambda () (interactive) (my/harpoon-jump 4))
    (kbd "<leader>5")  (lambda () (interactive) (my/harpoon-jump 5))
    (kbd "<leader>D")  #'dired-jump
    (kbd "<leader>ff") #'my/find-file
    (kbd "<leader>fg") #'consult-ripgrep
    (kbd "<leader>fb") #'consult-buffer
    (kbd "<leader>fl") #'consult-line
    (kbd "<leader>fi") #'consult-imenu
    (kbd "<leader>fh") #'describe-symbol
    (kbd "<leader>Q")  (lambda () (interactive) (dired user-emacs-directory))
    (kbd "<leader>z")  (lambda () (interactive) (my/doc-pane 60))
    (kbd "<leader>Z")  (lambda () (interactive) (my/doc-pane 40))
    (kbd "<leader>o")  #'my/open-results
    (kbd "<leader>pp") #'project-switch-project
    (kbd "<leader>pf") #'project-find-file
    (kbd "<leader>pg") #'consult-ripgrep
    (kbd "<leader>pd") #'project-dired
    (kbd "<leader>pk") #'project-kill-buffers
    (kbd "<leader>pb") #'consult-project-buffer
    (kbd "<leader>v")  #'my/markdown-toggle-preview
    (kbd "<leader>a")  #'org-agenda
    (kbd "<leader>c")  #'org-capture)

  ;; LSP keys, active only in Eglot-managed buffers
  (evil-define-key 'normal eglot-mode-map
    (kbd "gD") #'eglot-find-declaration
    (kbd "gd") #'xref-find-definitions
    (kbd "gt") #'eglot-find-typeDefinition
    (kbd "gi") #'eglot-find-implementation
    (kbd "gr") #'xref-find-references
    (kbd "K")  #'eldoc-doc-buffer
    (kbd "C-k") #'eldoc
    (kbd "<leader>rn") #'eglot-rename
    (kbd "<leader>ca") #'eglot-code-actions
    (kbd "<leader>F")  #'my/format-buffer)
  (evil-define-key 'insert eglot-mode-map (kbd "C-k") #'eldoc)
  (add-hook 'eglot-managed-mode-hook #'evil-normalize-keymaps)

  (evil-define-key 'normal my/harpoon-menu-mode-map
    (kbd "RET") #'my/harpoon-menu-select
    (kbd "q")   #'my/harpoon-menu-quit))

(use-package evil-collection
  :after evil
  :config
  (evil-collection-init))

;;; init.el ends here
