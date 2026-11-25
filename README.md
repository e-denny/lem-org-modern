# lem-org-modern

A modern style for Org buffers in Lem, modeled on Emacs
[org-modern](https://github.com/minad/org-modern).  Headlines, TODO keywords,
tags, timestamps, list bullets, checkboxes and rules are restyled without
changing the buffer text: the file stays an ordinary Org file and everything
remains editable.

This is a Lem port of org-modern's display-property idea, built on Lem
overlays.  Attribute-only overlays color labels; overlays with the `:display`
property draw replacement glyphs.  Every decoration is rebuilt after an edit,
so the view never drifts from the text.

## Commands

| Command | What it does |
| --- | --- |
| `org-modern-mode` | Toggle the style in the current buffer. |
| `global-org-modern-mode` | Enable it in every Org buffer, and in Org buffers opened later. |
| `org-modern-refresh` | Rebuild the decorations of the current buffer. |

`global-org-modern-mode` follows the major modes named in
`*org-modern-major-modes*` (default `("organ-mode")`).  Enable it after the Org
mode has been loaded, so the mode is registered and its hook can be found.

## What is styled

| Element | Result |
| --- | --- |
| Headline stars | Replaced by level glyphs `◉ ○ ◈ ◇ ✳`; the extra leading stars become spaces, so deeply nested headlines line up on their glyph. |
| `TODO`, `NEXT`, `WAIT`, `HOLD`, `STARTED` | Drawn as a colored label (background, dark foreground, bold). |
| `DONE`, `CANCELLED`, `CANCELED` | Drawn as a green label. |
| `[#A]` priority | Drawn as a yellow label. |
| `[1/3]`, `[50%]` progress cookies | Drawn as `▓▓░` bars of the same width as the cookie. |
| `:tag1:tag2:` at the end of a headline | Drawn as a single label. |
| `<2026-01-01 Thu 10:00>` / `[2026-01-01]` | Date and time drawn as labels; active and inactive timestamps differ. |
| `-`, `+`, `*` list bullets | Replaced with `–`, `◦`, `∙`. |
| `[ ]`, `[X]`, `[-]` checkboxes | Replaced with `☐`, `☑`, `◐`. |
| `-----` horizontal rules | Drawn as `─────`. |
| `#+keyword:` and `#+begin_` / `#+end_` | The `#+` prefix is dimmed and a block's type name is highlighted. |

Blocks (`#+begin_src` … `#+end_src`) are left to their language: only the
delimiter lines are decorated, and headlines or timestamps inside a block are
not touched.

## Differences from org-modern

Lem's attributes have no box, border or font scaling, and the frontend has no
fringe.  The differences that follow from that are deliberate:

- Labels are a background, foreground and bold, not a bordered box, and they do
  not use a smaller font.  Timestamps and tags keep their punctuation instead
  of hiding it.
- Headline stars are the static `org-modern-star 'replace` style.  Fold state is
  not shown as `▶`/`▼`; organ-mode's own fold placeholder still marks a fold.
- Tables are not redrawn with pixel-thin borders; organ-mode's table
  highlighting is left alone.
- There are no block fringe bars, link targets, radio targets, footnotes,
  habits, or keep/focus-line handling.
- Putting a cursor inside a replaced token (a checkbox, say) shows the cursor
  at the start of the replacement, because Lem maps buffer positions through
  the display splice.  The underlying text is still editable.

## Configuration

All knobs are exported from `lem-org-modern`.

```lisp
;; Glyphs for levels 1..5; the last one is reused for deeper levels.
(setf lem-org-modern:*org-modern-stars* '("◆" "◇" "▸" "▹" "·"))

;; Faces per level, in the same order.
(setf lem-org-modern:*org-modern-star-attributes*
      '(org-modern-star-1-attribute
        org-modern-star-2-attribute
        org-modern-star-3-attribute
        org-modern-star-4-attribute
        org-modern-star-5-attribute))

;; Which keywords count as TODO and as DONE.
(setf lem-org-modern:*org-modern-todo-keywords* '("TODO" "NEXT"))
(setf lem-org-modern:*org-modern-done-keywords* '("DONE" "CANCELLED"))

;; List bullets and checkboxes, keyed by the character they replace.
(setf lem-org-modern:*org-modern-bullets*
      '((#\- . "–") (#\+ . "◦") (#\* . "∙")))
(setf lem-org-modern:*org-modern-checkboxes*
      '((#\Space . "☐") (#\X . "☑") (#\x . "☑") (#\- . "◐")))

;; Turn individual elements off.
(setf lem-org-modern:*org-modern-timestamp* nil)
(setf lem-org-modern:*org-modern-tag* nil)
(setf lem-org-modern:*org-modern-progress* nil)

;; Follow another major mode that uses Org syntax as well.
(setf lem-org-modern:*org-modern-major-modes* '("organ-mode" "my-org-mode"))
```

Faces can be restyled like any Lem attribute, e.g.
`(lem:define-attribute org-modern-todo-attribute (t :foreground :base00
:background :base0e :bold t))` or by editing `faces.lisp`.  Colors use the
theme's `:base00`–`:base0F` palette, so the style follows the active theme.

## Loading

```lisp
(pushnew (merge-pathnames "extensions/org-modern/" (lem-home))
         asdf:*central-registry* :test #'equal)
(asdf:load-system "lem-org-modern")
(lem-org-modern:global-org-modern-mode t)
```

`init.lisp` in this configuration loads it after organ-mode and turns the
global mode on.

## Implementation notes

- Decorations are kept in a per-buffer overlay list, tagged separately from
  organ-mode's syntax overlays, so neither redraw deletes the other's work.
- After an edit, the buffer is rescanned line by line.  This matches what
  organ-mode already does (it reparses the whole buffer per change), and the
  scan is a handful of regular expressions per line.
- Lines hidden by a fold are skipped, because a fold already replaces its
  region with a placeholder; decorating inside it too would splice the same
  characters twice.  Folding and unfolding only create or delete overlays, so
  they do not run `after-change-functions`; a pre-command/post-command check
  compares the buffer's fold positions and rebuilds when they change.
- The decoration overlays are moved to the end of the buffer's overlay list
  after each rebuild.  Lem applies overlay attributes from the newest overlay
  to the oldest, with later ones winning, so this is what lets the modern faces
  take precedence over organ-mode's syntax highlighting on the same characters.
- Display replacements keep the character count of what they replace wherever
  possible, so the editing grid does not move.  Checkboxes are the exception,
  as in org-modern.

## Verification

The extension was exercised in a live Lem with organ-mode: headline stars of
several levels, TODO/DONE/priority labels, tags, active and inactive
timestamps with times, `[ ]`/`[X]`/`[-]` checkboxes, `-`/`+` bullets, a rule,
progress cookies, a `#+begin_src` block whose body stayed untouched, and the
same file folded and unfolded.  The rendered logical lines and their merged
attributes were checked through Lem's `create-logical-line`, and the mode was
enabled and disabled through `org-modern-mode` and `global-org-modern-mode`.
