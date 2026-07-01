return {
  {
    "nvim-neo-tree/neo-tree.nvim",

    opts = {
      filesystem = {
        filtered_items = {
          -- Показывать отфильтрованные файлы, но другим цветом
          visible = true,

          -- Файлы из .gitignore считаются отфильтрованными
          hide_gitignored = true,
          hide_ignored = true,

          -- Обычные dotfiles показываем нормально
          hide_dotfiles = false,
          hide_hidden = false,
        },
      },

      default_component_configs = {
        name = {
          use_filtered_colors = true,
          use_git_status_colors = true,
        },

        icon = {
          use_filtered_colors = true,
        },

        git_status = {
          symbols = {
            ignored = "",
          },
        },
      },
    },

    init = function()
      local function set_neo_tree_highlights()
        vim.api.nvim_set_hl(0, "NeoTreeGitIgnored", {
          link = "Comment",
        })

        vim.api.nvim_set_hl(0, "NeoTreeDotfile", {
          link = "Comment",
        })
      end

      set_neo_tree_highlights()

      -- Чтобы цвет не сбрасывался после смены темы
      vim.api.nvim_create_autocmd("ColorScheme", {
        callback = set_neo_tree_highlights,
      })
    end,
  },
}
