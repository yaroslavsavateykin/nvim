# Neovim configuration

Персональная конфигурация [AstroNvim](https://astronvim.com/) для Neovim. Плагины фиксируются в `lazy-lock.json` и устанавливаются автоматически при первом запуске.

Основное окружение: Linux, [Ghostty](https://ghostty.org/) и шрифт с Nerd Font glyphs. Ghostty используется как мой терминал; конфигурация Neovim не зависит от него жёстко, но его удобно использовать с Nerd Font для корректных иконок и глифов интерфейса.

## Базовые зависимости

| Компонент | Назначение | Обязателен |
| --- | --- | --- |
| Neovim 0.11+ | Редактор и Lua API, используемый конфигурацией | Да |
| Git | Автоматическая загрузка `lazy.nvim` и плагинов | Да |
| Nerd Font | Иконки файлов, статуса и интерфейса | Рекомендуется |
| `wl-clipboard` или `xclip` | Системный буфер обмена в Linux | Рекомендуется |
| Ghostty | Предпочитаемый терминал | Рекомендуется |

### Ubuntu / Debian

Установите базовые пакеты. В некоторых стабильных выпусках дистрибутива Neovim старее 0.11, поэтому в таком случае используйте официальный AppImage, пакет из PPA или сборку Neovim вместо репозиторного пакета.

```bash
sudo apt update
sudo apt install git neovim wl-clipboard xclip
```

### Arch Linux

```bash
sudo pacman -S git neovim wl-clipboard xclip
```

Установите Ghostty способом, рекомендованным для вашего дистрибутива, и выберите в его настройках Nerd Font, например `JetBrainsMono Nerd Font`.

## Установка конфигурации

```bash
git clone https://github.com/yaroslavsavateykin/nvim.git ~/.config/nvim
nvim
```

При первом запуске `init.lua` сам клонирует `lazy.nvim`, после чего lazy.nvim установит плагины, зафиксированные в `lazy-lock.json`. Дождитесь окончания установки и перезапустите Neovim. Для диагностики используйте `:Lazy`, а для обновления плагинов - `:Lazy update`.

Если `~/.config/nvim` уже существует, предварительно переместите или удалите старую конфигурацию, чтобы `git clone` не затронул её неявно.

## Дополнительные возможности

Эти программы нужны не для запуска редактора, а для соответствующих настроенных возможностей.

| Возможность | Внешняя зависимость | Установка |
| --- | --- | --- |
| Lua LSP и форматирование | `lua-language-server`, `stylua` | Автоматически через Mason |
| Python LSP и форматирование | `basedpyright`, `ruff` | Автоматически через Mason |
| Typst LSP и форматирование | `tinymist`, `typstyle` | Автоматически через Mason |
| Редактирование и компиляция Typst | `typst` | `cargo install typst-cli` |
| Jupyter notebooks (`.ipynb`) | Python 3, Jupyter/IPython | `python3 -m pip install --user jupyter ipython` |
| marimo notebooks (`.py`) | Python 3 и `marimo` | `python3 -m pip install --user marimo` |
| Вставка изображений в Typst | `wl-clipboard` в Wayland или `xclip` в X11 | См. базовые зависимости |
| PDF в терминале | `fancy-cat` | `cargo install --git https://github.com/freref/fancy-cat.git` |
| Интеграция OpenCode | CLI `opencode` | Установите по [инструкции OpenCode](https://opencode.ai/docs) |

Mason управляет языковыми серверами и форматтерами внутри Neovim. Откройте `:Mason`, чтобы проверить или переустановить их. Команды `:LspInfo` и `:ConformInfo` показывают состояние LSP и форматирования в текущем буфере.

### Typst

Для `.typ` включены Tinymist, форматирование `typstyle` при сохранении и вставка изображения через `<leader>ip`. `typstyle` получает Mason автоматически; бинарник `typst` устанавливается отдельно, потому что он требуется для компиляции документов, а не для LSP.

### Python, Jupyter и marimo

Для Python автоматически устанавливаются `basedpyright` и `ruff`; `ruff` форматирует Python-файлы. Для запуска ядер, notebooks и marimo нужен Python-пакет в активном окружении. Предпочтительно создать venv проекта и установить пакеты в него:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install --upgrade pip
.venv/bin/python -m pip install jupyter ipython marimo
```

Плагин `venv-selector.nvim` позволяет выбрать это окружение в Neovim. Marimo запускается командой `:MarimoStart` для сохранённого `.py` файла.

### Ghostty и fancy-cat

Я использую Ghostty как терминальный эмулятор. Он хорошо подходит для плавающих терминалов Neovim и Nerd Font-иконок. Убедитесь, что `ghostty` доступен из `PATH`:

```bash
ghostty --version
```

`fancy-cat` - полезная утилита для просмотра PDF прямо в терминале. Установите её из исходного репозитория через Cargo:

```bash
cargo install --git https://github.com/freref/fancy-cat.git
```

После установки она вызывается так:

```bash
fancy-cat document.pdf
fancy-cat document.pdf 3
```

Проверьте, что каталог Cargo с бинарниками присутствует в `PATH`:

```bash
export PATH="$HOME/.cargo/bin:$PATH"
fancy-cat --version
```

Чтобы сделать это постоянным, добавьте экспорт `PATH` в конфигурацию используемой оболочки.

## Проверка установки

После первого запуска проверьте основу окружения:

```bash
nvim --version
git --version
ghostty --version
```

Для полной конфигурации с Typst, Python и PDF дополнительно:

```bash
typst --version
fancy-cat --version
python3 --version
```

В Neovim выполните `:checkhealth`, `:Lazy` и `:Mason`. Они покажут отсутствующие зависимости и состояние установленных компонентов.
