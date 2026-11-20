# Emacs config

Vim-style (Evil) Emacs 31 setup for WSL (WSLg, Wayland/pgtk). Built mostly on
native Emacs features (Eglot, tree-sitter, fido-vertical, project.el, flymake,
eldoc) plus a few small packages: evil, evil-collection, consult, corfu,
yasnippet, vterm, tuareg/ocaml-eglot/utop/dune, eglot-booster and the
gruber-darker theme.

## Install

```bash
git clone git@github.com:AngelVI13/new_emacs_conf.git ~/.emacs.d
systemctl --user enable --now ~/.emacs.d/emacs.service   # start the daemon
echo "alias emacs='emacsclient -c -n -a \"\"'" >> ~/.bashrc
```

Packages install automatically on the first start; tree-sitter grammars are
compiled the first time a language is opened.

## Daemon / client

- `emacs.service` is a systemd user service running `emacs --fg-daemon`. It
  starts with WSL (requires linger) through a login shell, so `~/.profile`
  provides PATH and the opam environment. Go paths from `~/.bashrc` are added
  in `init.el`.
- `emacs [file]` (alias for `emacsclient -c -n -a ""`) opens a new maximized
  frame connected to the daemon; it starts a daemon if none is running.
- Closing a frame keeps the daemon alive. Reload the whole config with
  `systemctl --user restart emacs` (closes all frames), or evaluate changed
  forms in place with `C-x C-e` / `M-x eval-region`.

## Building Emacs 31 (Ubuntu 24.04)

```bash
sudo apt install build-essential git autoconf texinfo pkg-config \
  libgtk-3-dev libgnutls28-dev libgccjit-13-dev libxml2-dev libharfbuzz-dev \
  libcairo2-dev libjpeg-dev libpng-dev libtiff-dev libgif-dev libwebp-dev \
  librsvg2-dev libsqlite3-dev libncurses-dev libacl1-dev libgpm-dev \
  libm17n-dev libotf-dev libdbus-1-dev libtool-bin cmake

# tree-sitter (Ubuntu's 0.20 is too old)
git clone --depth 1 --branch v0.25.10 https://github.com/tree-sitter/tree-sitter.git ~/src/tree-sitter
make -C ~/src/tree-sitter -j$(nproc) PREFIX=$HOME/.local install

# Emacs
cd ~/src && wget https://ftp.gnu.org/gnu/emacs/emacs-31.1.tar.xz && tar xf emacs-31.1.tar.xz
cd emacs-31.1
PKG_CONFIG_PATH=$HOME/.local/lib/pkgconfig CPPFLAGS=-I$HOME/.local/include \
LDFLAGS="-L$HOME/.local/lib -Wl,-rpath,$HOME/.local/lib" \
./configure --prefix=$HOME/.local --with-pgtk --with-native-compilation=aot \
  --with-tree-sitter --with-modules --with-sqlite3 --with-rsvg --with-webp
make -j$(nproc) && make install
```

WSL must be 2.6.0 or newer (`wsl --update`), otherwise `/run/user/$UID` breaks
under systemd. Enable lingering: `sudo loginctl enable-linger $USER`.

## External tools

| Tool | Used for |
|---|---|
| `rg`, `fd` | project search / file finding (consult-ripgrep, project.el) |
| `aspell`, `aspell-en` | spell checking (flyspell) |
| `emacs-lsp-booster` | faster LSP I/O (eglot-booster) |
| `rass`, `ty`, `ruff` (`uv tool install rassumfrassum ty ruff`) | Python LSP via `bin/python-lsp`; a project's `.venv` versions take precedence |
| `gopls`, `gofumpt`, `golines` | Go LSP and formatting |
| `ocamllsp`, `ocamlformat`, `utop`, `dune` | OCaml (via opam) |
| `prettier` | HTML/CSS/JS format on save |
| `cmake`, `libtool-bin` | building the vterm module |
| Iosevka Term font | `~/.local/share/fonts` (ligatures enabled in code buffers) |

## Features

- **Completion**: corfu popup opens automatically after 3 characters or right
  after `.`; documentation popup next to it. Sources: LSP, then words from
  buffers. Minibuffer completion uses native `fido-vertical-mode`.
- **LSP** (Eglot): Python (ty + ruff via rass), Go (gopls, gofumpt, staticcheck),
  OCaml (ocamllsp + ocaml-eglot). Inline diagnostics at end of line.
- **Docs pane**: `SPC z` opens a left pane with the `*eldoc*` buffer. Normal
  state shows hover info, insert state shows signature help; the echo area is
  skipped while the pane is visible.
- **Search**: live ripgrep with `consult-ripgrep` (no preview, RET opens).
  Input is passed to rg: `foo bar` (both words), `"foo bar"` (phrase),
  trailing flags like `-tpy`, `-g *.ml`, `-C2`. `C-q` in the prompt saves the
  results into a `*grep: ...*` buffer (`SPC o` reopens it, `g` re-runs).
- **Projects**: project.el remembers a git project when a file or directory in
  it is opened; `SPC p p` lists known projects and opens find-file in the pick.
- **Format on save**: Go (gopls + `golines -m 90`), OCaml (ocamlformat),
  HTML/CSS/JS (prettier). Toggle with `M-x my/toggle-format-on-save`.
- **Notes**: Org (`~/Documents/notes`), Markdown via native `markdown-ts-mode`
  with a rendered preview (`SPC v`).
- **Harpoon-like file slots**: up to 5 files, saved across sessions.

## Key bindings

Leader is `SPC` (which-key shows the rest). `jk` leaves insert mode (also in vterm).

| Key | Action |
|---|---|
| `SPC ff` / `SPC pf` | find file (current project) |
| `SPC fg` / `SPC pg` | live ripgrep in project |
| `SPC fb` / `SPC pb` | switch buffer (all / project) |
| `SPC fl` / `SPC fi` | search lines in buffer / jump to symbol (imenu) |
| `SPC fh` | describe symbol |
| `SPC pp` / `SPC pd` / `SPC pk` | switch project / project dired / kill project buffers |
| `SPC o` | show last grep/xref results |
| `SPC e` / `SPC E` / `SPC q` | line diagnostics / project / buffer diagnostics |
| `SPC [` / `SPC ]` | previous / next diagnostic |
| `SPC t` / `SPC T` | terminal (vterm) / project TODOs |
| `SPC z` / `SPC Z` | toggle docs pane (60 / 40 columns) |
| `SPC H` / `SPC h` / `SPC 1-5` | harpoon: add file / edit list / jump |
| `SPC D` / `SPC Q` | dired here / dired in `~/.emacs.d` |
| `SPC v` | Markdown preview toggle |
| `SPC a` / `SPC c` | org agenda / org capture |
| `gd` `gD` `gt` `gi` `gr` | definition / declaration / type / implementation / references |
| `K` / `C-k` | docs buffer / eldoc (signature in insert state) |
| `SPC rn` / `SPC ca` / `SPC F` | rename / code actions / format (+ organize imports in Python) |

Completion popup: `RET` accept, `C-n`/`C-p` (or `C-j`/`C-k`) move, `C-e` close,
`C-f`/`C-b` scroll docs, `C-SPC` trigger manually.

## Notes

- Font: `my/font-size` x `my/display-scale` in `early-init.el`. WSLg does not
  apply Windows display scaling, so raise `my/display-scale` if text looks small.
- Packages are not refreshed at startup; update with `M-x package-upgrade-all`.