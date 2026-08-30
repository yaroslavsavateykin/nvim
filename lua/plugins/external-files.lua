local external_file_patterns = {
  -- PDF
  "*.pdf",
  "*.PDF",

  -- Изображения
  "*.png",
  "*.PNG",
  "*.jpg",
  "*.JPG",
  "*.jpeg",
  "*.JPEG",
  "*.webp",
  "*.WEBP",
  "*.gif",
  "*.GIF",
  "*.bmp",
  "*.BMP",
  -- "*.svg",
  "*.SVG",
  "*.tif",
  "*.TIF",
  "*.tiff",
  "*.TIFF",

  -- Текстовые и офисные документы
  "*.doc",
  "*.DOC",
  "*.docx",
  "*.DOCX",
  "*.odt",
  "*.ODT",
  "*.rtf",
  "*.RTF",

  -- Таблицы
  "*.xls",
  "*.XLS",
  "*.xlsx",
  "*.XLSX",
  "*.ods",
  "*.ODS",

  -- Презентации
  "*.ppt",
  "*.PPT",
  "*.pptx",
  "*.PPTX",
  "*.odp",
  "*.ODP",

  -- Аудио
  "*.mp3",
  "*.MP3",
  "*.wav",
  "*.WAV",
  "*.flac",
  "*.FLAC",
  "*.ogg",
  "*.OGG",

  -- Видео
  "*.mp4",
  "*.MP4",
  "*.mkv",
  "*.MKV",
  "*.webm",
  "*.WEBM",
  "*.avi",
  "*.AVI",
  "*.mov",
  "*.MOV",
}

return {
  {
    "AstroNvim/astrocore",

    opts = function(_, opts)
      opts.autocmds = opts.autocmds or {}

      opts.autocmds.open_external_files = {
        {
          event = "BufReadCmd",
          pattern = external_file_patterns,
          desc = "Open binary files with the default system application",

          callback = function(args)
            local path = vim.api.nvim_buf_get_name(args.buf)

            if path == "" then
              return
            end

            path = vim.fn.fnamemodify(path, ":p")

            local _, err = vim.ui.open(path)

            if err then
              vim.notify(
                ("Не удалось открыть файл:\n%s\n\n%s"):format(
                  path,
                  err
                ),
                vim.log.levels.ERROR
              )

              return
            end

            -- Убираем пустой буфер, созданный для внешнего файла.
            vim.schedule(function()
              if vim.api.nvim_buf_is_valid(args.buf) then
                pcall(
                  vim.api.nvim_buf_delete,
                  args.buf,
                  { force = true }
                )
              end
            end)
          end,
        },
      }
    end,
  },
}
