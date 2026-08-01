return {
  {
    "sheng-tse/jupynvim",

    build = function(plugin)
      local install =
        loadfile(plugin.dir .. "/lua/jupynvim/install.lua")()

      install.run(plugin)
    end,

    config = function()
      require("jupynvim").setup({
        log_level = "info",

        -- Лучший режим для Ghostty.
        -- Изображение прикреплено к тексту и нормально прокручивается.
        image_renderer = "placeholder",

        -- Размер графиков в ячейках терминала.
        image_rows = 18,
        image_cols = 60,

        -- Автоматически искать .venv проекта.
        auto_venv = true,

        -- Плавная прокрутка иногда сбивает положение изображений.
        smooth_scroll = false,
      })
    end,
  },
}
