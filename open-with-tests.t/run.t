PDF:
  $ docfd --index-only --open-with pdf:fg='okular {path}'
  $ docfd --index-only --open-with pdf:fg='okular {page_num}'
  $ docfd --index-only --open-with pdf:fg='okular {line_num}'
  error: failed to parse pdf:fg=okular {line_num}, line_num not available
  [1]
  $ docfd --index-only --open-with pdf:fg='okular {search_word}'

Text:
  $ docfd --index-only --open-with txt:fg='nano {path}'
  $ docfd --index-only --open-with txt:fg='nano {page_num}'
  error: failed to parse txt:fg=nano {page_num}, page_num not available
  [1]
  $ docfd --index-only --open-with txt:fg='nano {line_num}'
  $ docfd --index-only --open-with txt:fg='nano {search_word}'
  error: failed to parse txt:fg=nano {search_word}, search_word not available
  [1]
