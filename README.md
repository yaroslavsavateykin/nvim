# Neovim конфиг на базе AstroNvim

Этот репозиторий — личная конфигурация Neovim, собранная поверх **AstroNvim v5** и **lazy.nvim**.
Содержит минимальные пользовательские изменения, а большую часть поведения наследует из AstroNvim.

## Возможности и особенности

- Основа: AstroNvim + lazy.nvim.
- Лидер-клавиши: `mapleader = " "`, `maplocalleader = ","` (см. `lua/lazy_setup.lua`).
- Буфер обмена по умолчанию: `unnamedplus` (Linux), плюс `unnamed` (см. `init.lua`).
- Быстрые правки выделения при `>`/`<` в визуальном режиме.
- Файловый менеджер: **nvim-tree** вместо neo-tree.
- Встроенный терминал: **toggleterm**, хоткей `Ctrl-t`.
- Выбор Python venv: **venv-selector**, хоткей `,v`.
- Комментирование: **Comment.nvim**.

> Многие расширенные модули AstroNvim сохранены как заготовки, но **отключены** (см. раздел «Включение заготовок»).

## Требования

Минимально необходимы:

- **Neovim**: версия, совместимая с AstroNvim v5 (обычно `0.9+`).
- **Git**: требуется для установки lazy.nvim и плагинов.
- **Nerd Font** (рекомендуется) для иконок.
- **fd**: используется `venv-selector` для поиска Python окружений (см. `lua/plugins/venv-selector.lua`).
- Системный буфер обмена:
  - Linux (X11): `xclip` или `xsel`.
  - Linux (Wayland): `wl-clipboard`.

Опционально (в зависимости от ваших задач):

- **Python 3**: для работы `nvim-dap-python` и venv.
- LSP/форматтеры/линтеры — обычно ставятся через AstroNvim/Mason.

## Установка

1. Сделайте бэкап текущей конфигурации, если есть:

```bash
mv ~/.config/nvim ~/.config/nvim.bak
```

2. Склонируйте этот конфиг:

```bash
git clone <ваш-репозиторий> ~/.config/nvim
```

3. Запустите Neovim:

```bash
nvim
```

При первом запуске `lazy.nvim` автоматически скачает AstroNvim и плагины.

## Первый запуск

- Дождитесь установки плагинов.
- Проверьте, что Neovim видит `git` и доступ к сети.
- При необходимости установите доп. инструменты через `:Mason`.

Полезные команды:

- `:Lazy` — менеджер плагинов (обновление, синхронизация).
- `:Mason` — установка LSP/форматтеров/линтеров.

## Использование

### Базовые хоткеи

- `Ctrl-t` — открыть/закрыть терминал (normal/insert/terminal).
- `,v` — выбор Python venv (`VenvSelect`).
- В визуальном режиме `>` и `<` сохраняют выделение.

### Файловый менеджер

- Используется `nvim-tree`.
- Основные команды доступны через `:NvimTreeToggle` / `:NvimTreeFocus`.

### Комментарии

- `Comment.nvim` использует стандартные хоткеи типа `gcc` / `gc`.

## Включение заготовок AstroNvim

В проекте есть файлы с примерами и расширенными настройками, но они **отключены** строчкой:

```lua
if true then return {} end
```

Чтобы активировать, удалите эту строку из нужного файла:

- `lua/community.lua`
- `lua/polish.lua`
- `lua/plugins/astrocore.lua`
- `lua/plugins/astrolsp.lua`
- `lua/plugins/astroui.lua`
- `lua/plugins/mason.lua`
- `lua/plugins/none-ls.lua`
- `lua/plugins/treesitter.lua`
- `lua/plugins/user.lua`

После активации перезапустите Neovim и выполните `:Lazy sync`.

## Структура проекта

- `init.lua` — точка входа, bootstrap lazy.nvim и базовые правки.
- `lua/lazy_setup.lua` — основной список плагинов (AstroNvim + imports).
- `lua/plugins/` — пользовательские плагины и настройки.
- `lazy-lock.json` — зафиксированные версии плагинов.

## Частые проблемы

- **Не работает системный буфер обмена** — установите `xclip`/`xsel`/`wl-clipboard`.
- **Не находятся venv** — проверьте наличие `fd` и корректность команды в `lua/plugins/venv-selector.lua`.
- **Иконки не отображаются** — установите Nerd Font или отключите иконки в `lua/lazy_setup.lua`.

## Обновление

- Обновить плагины: `:Lazy update`
- Обновить AstroNvim: тем же способом через `:Lazy update`

## Кастомизация

Основные места для изменений:

- Общие настройки и маппинги: `lua/plugins/astrocore.lua` (после активации).
- LSP: `lua/plugins/astrolsp.lua`.
- UI/темы: `lua/plugins/astroui.lua`.
- Пользовательские плагины: `lua/plugins/user.lua`.

Если нужно изменить путь поиска venv — правьте блок `search` в `lua/plugins/venv-selector.lua`.
