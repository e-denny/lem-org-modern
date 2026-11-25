(in-package :lem-org-modern)

;;; The decoration engine.
;;;
;;; A decoration is a Lem overlay.  Attribute-only overlays color a range
;;; (TODO labels, tags, timestamps); overlays with the :display property draw
;;; replacement text instead (stars, bullets, checkboxes, rules).  The buffer
;;; text is never modified, so the file stays a normal Org file and every
;;; decoration is recomputed after an edit.

(defvar *org-modern-major-modes* '("organ-mode")
  "Major modes in which `global-org-modern-mode` turns `org-modern-mode` on.
Names are compared with `string-equal` against the mode's name, so a mode has
to be registered before `global-org-modern-mode` is enabled to be picked up.")

(declaim (ftype (function (buffer point t) t) org-modern--decorate-line))

(define-overlay-accessors org-modern-overlays
  :clear-function org-modern--clear-overlays
  :add-function org-modern--add-overlay)

(defun org-modern--enabled-p (buffer)
  "T when `org-modern-mode` is on in BUFFER."
  (buffer-value buffer 'org-modern-enabled))

(defun org-modern--decorate (buffer line-start start end attribute
                             &optional display)
  "Decorate columns START..END of the line at LINE-START in BUFFER.
ATTRIBUTE names the face.  With DISPLAY, those columns are drawn as the string
DISPLAY instead of their own text; START..END are zero-based character offsets
into the line, LINE-START is a point at the line's beginning."
  (when (< start end)
    (with-point ((from line-start))
      (character-offset from start)
      (with-point ((to line-start))
        (character-offset to end)
        (when display
          (let ((overlay (make-overlay from to attribute)))
            (overlay-put overlay :display (list display attribute))
            (org-modern--add-overlay buffer overlay)))
        ;; The attribute-only overlay is what makes the face win over the
        ;; syntax highlighting already on these characters: a display overlay
        ;; is skipped when attributes are merged, so it cannot outrank the
        ;; mode's own overlay on its own.
        (let ((overlay (make-overlay from to attribute)))
          (org-modern--add-overlay buffer overlay)
          overlay)))))

(defun org-modern--fold-signature (buffer)
  "The buffer positions where the folds in BUFFER currently begin.
Used to notice fold and unfold commands, which change overlays without
changing the buffer text and therefore never run `after-change-functions`."
  (let ((positions '()))
    (dolist (overlay (buffer-overlays buffer) (nreverse positions))
      (when (overlay-get overlay :fold)
        (push (position-at-point (overlay-start overlay)) positions)))))

(defun org-modern--redraw (buffer)
  "Rebuild every org-modern decoration in BUFFER.
Hidden lines are skipped: a fold already replaces its region with a
placeholder, and decorating text inside it as well would splice the same
characters twice when the line is drawn."
  (org-modern--clear-overlays buffer)
  (when (org-modern--enabled-p buffer)
    (let ((in-block nil))
      (with-point ((point (buffer-start-point buffer)))
        (loop
          (with-point ((line-start-point point))
            (line-start line-start-point)
            (unless (invisible-overlay-covering line-start-point)
              (setf in-block
                    (org-modern--decorate-line buffer point in-block))))
          (unless (line-offset point 1)
            (return)))))
    (setf (buffer-value buffer 'org-modern-fold-signature)
          (org-modern--fold-signature buffer))
    (org-modern--demote-overlays buffer))
  buffer)

(defun org-modern--demote-overlays (buffer)
  "Move the org-modern overlays to the end of BUFFER's overlay list.
Lem applies overlay attributes from the newest overlay to the oldest and lets
later ones override earlier ones, so the end of the list wins.  Demoting the
decorations keeps their colors instead of letting organ-mode's highlighting
recolor the same characters."
  (let ((ours (org-modern-overlays buffer))
        (all (buffer-value buffer 'lem-core::overlays)))
    (when ours
      (setf (buffer-value buffer 'lem-core::overlays)
            (append (remove-if (lambda (overlay)
                                 (member overlay ours :test #'eq))
                               all)
                    ours)))))

(defun org-modern--after-change (start end length)
  "Rebuild the decorations of the changed buffer."
  (declare (ignore end length))
  (let ((buffer (point-buffer start)))
    (when (org-modern--enabled-p buffer)
      (org-modern--redraw buffer))))

(defun org-modern--post-command ()
  "Refresh decorations when the current buffer's folds changed.
Folding and unfolding create and delete overlays only, so no change hook runs;
the fold signature is cheap to compare on every command."
  (let ((buffer (current-buffer)))
    (when (org-modern--enabled-p buffer)
      (unless (equal (org-modern--fold-signature buffer)
                     (buffer-value buffer 'org-modern-fold-signature))
        (org-modern--redraw buffer)))))

;;; Minor modes.

(defun org-modern--enable ()
  "Turn `org-modern-mode` on in the current buffer."
  (let ((buffer (current-buffer)))
    (unless (org-modern--enabled-p buffer)
      (setf (buffer-value buffer 'org-modern-enabled) t)
      (add-hook (variable-value 'after-change-functions :buffer buffer)
                'org-modern--after-change
                -1)
      (org-modern--redraw buffer))))

(defun org-modern--disable ()
  "Turn `org-modern-mode` off in the current buffer."
  (let ((buffer (current-buffer)))
    (when (org-modern--enabled-p buffer)
      (setf (buffer-value buffer 'org-modern-enabled) nil)
      (remove-hook (variable-value 'after-change-functions :buffer buffer)
                   'org-modern--after-change)
      (org-modern--clear-overlays buffer))))

(define-minor-mode org-modern-mode
    (:name "Org-Modern"
     :description "Modern styling for Org buffers."
     :enable-hook 'org-modern--enable
     :disable-hook 'org-modern--disable
     :hide-from-modeline t))

(defun org-modern--matching-major-modes ()
  "Registered major modes named in `*org-modern-major-modes*`."
  (remove-if-not
   (lambda (mode)
     (member (string-downcase (string mode))
             *org-modern-major-modes*
             :test #'string-equal))
   (major-modes)))

(defun org-modern--eligible-buffer-p (buffer)
  "T when BUFFER's major mode is one `org-modern-mode` should follow."
  (member (string-downcase (string (buffer-major-mode buffer)))
          *org-modern-major-modes*
          :test #'string-equal))

(defun org-modern--enable-here ()
  "Mode hook entry: turn `org-modern-mode` on in the buffer being set up."
  (org-modern-mode t))

(defun org-modern--install-mode-hooks ()
  "Arrange for new buffers in the configured major modes to be decorated."
  (dolist (mode (org-modern--matching-major-modes))
    (let ((hook-variable (mode-hook-variable mode)))
      (when hook-variable
        (let ((hooks (symbol-value hook-variable)))
          (unless (assoc 'org-modern--enable-here hooks)
            (setf (symbol-value hook-variable)
                  (acons 'org-modern--enable-here 0 hooks))))))))

(defun org-modern--remove-mode-hooks ()
  "Stop decorating new buffers in the configured major modes."
  (dolist (mode (major-modes))
    (let ((hook-variable (ignore-errors (mode-hook-variable mode))))
      (when hook-variable
        (setf (symbol-value hook-variable)
              (delete 'org-modern--enable-here
                      (symbol-value hook-variable)
                      :key #'car))))))

(defun org-modern--global-enable ()
  "Decorate every matching buffer and every matching buffer opened later."
  (org-modern--install-mode-hooks)
  (dolist (buffer (buffer-list))
    (when (org-modern--eligible-buffer-p buffer)
      (with-current-buffer buffer
        (org-modern-mode t)))))

(defun org-modern--global-disable ()
  "Stop decorating buffers and remove the mode hooks."
  (org-modern--remove-mode-hooks)
  (dolist (buffer (buffer-list))
    (when (mode-active-p buffer 'org-modern-mode)
      (with-current-buffer buffer
        (org-modern-mode nil)))))

(define-minor-mode global-org-modern-mode
    (:name "Global Org-Modern"
     :description "Modern styling in every Org buffer."
     :global t
     :enable-hook 'org-modern--global-enable
     :disable-hook 'org-modern--global-disable
     :hide-from-modeline t))

;; Fold changes are overlay changes, so they need a post-command check.  The
;; hook is installed once; it does nothing in buffers without the mode.
(add-hook *post-command-hook* 'org-modern--post-command)

(define-command org-modern-refresh () ()
  "Rebuild the org-modern decorations of the current buffer."
  (org-modern--redraw (current-buffer)))
