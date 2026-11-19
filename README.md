# Emacs config

Vim-style (Evil) Emacs 31 setup for WSL (WSLg, Wayland/pgtk), mostly built on
native Emacs features: Eglot (LSP), tree-sitter, fido-vertical, completion-preview,
project.el and flymake.

## Install

```bash
git clone git@github.com:AngelVI13/new_emacs_conf.git ~/.emacs.d
```

Packages install automatically on the first start; tree-sitter grammars are
compiled the first time a language is opened.

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
| `rg`, `fd` | project search / file finding |
| `aspell`, `aspell-en` | spell checking (flyspell) |
| `emacs-lsp-booster` | faster LSP I/O (eglot-booster) |
| `uv` + `rass`, project `ty`/`ruff` | Python LSP (`uv run rass python`) |
| `gopls`, `gofumpt`, `golines` | Go LSP and formatting |
| `ocamllsp`, `ocamlformat`, `utop`, `dune` | OCaml (via opam) |
| `prettier` | HTML/CSS/JS format on save |
| `cmake`, `libtool-bin` | building the vterm module |
| Iosevka Term font | `~/.local/share/fonts` |

## Notes

- Font size is set in `early-init.el` (`my/font-size` x `my/display-scale`,
  since WSLg does not apply Windows display scaling).
- Packages are not refreshed at startup; update with `M-x package-upgrade-all`.
- Leader key is `SPC`; press it to see all bindings (which-key).