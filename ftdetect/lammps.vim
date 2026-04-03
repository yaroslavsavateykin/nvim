augroup filetypedetect
  au! BufRead,BufNewFile in.* set filetype=lammps
  au! BufRead,BufNewFile *.lmp set filetype=lammps
  au! BufRead,BufNewFile *.lammps set filetype=lammps
augroup END
