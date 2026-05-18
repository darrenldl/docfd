Error case tests:
  $ docfd --index-only --open-with pdf:term='okular {path}'
  error: failed to parse pdf:term=okular {path}, invalid launch mode
  [1]
  $ docfd --index-only --open-with pdf='okular {path}'
  error: failed to parse pdf=okular {path}, expected char :
  [1]
  $ docfd --index-only --open-with pdfterminal='okular {path}'
  error: failed to parse pdfterminal=okular {path}, expected char :
  [1]
  $ docfd --index-only --open-with pdf:terminal='okular path}'
  Initializing in-memory index
  $ docfd --index-only --open-with pdf:terminal='okular {path'
  error: failed to parse pdf:terminal=okular {path, expected char }
  [1]
  $ docfd --index-only --open-with pdf:terminal='okular {abc}'
  error: failed to parse pdf:terminal=okular {abc}, invalid placeholder
  [1]

PDF parsing test, terminal launch mode:
  $ docfd --index-only --open-with pdf:terminal='okular {path}'
  Initializing in-memory index
  $ docfd --index-only --open-with pdf:terminal='okular {page_num}'
  Initializing in-memory index
  $ docfd --index-only --open-with pdf:terminal='okular {line_num}'
  error: failed to parse pdf:terminal=okular {line_num}, line_num not available
  [1]
  $ docfd --index-only --open-with pdf:terminal='okular {search_word}'
  Initializing in-memory index

PDF parsing test, detached launch mode:
  $ docfd --index-only --open-with pdf:detached='okular {path}'
  Initializing in-memory index
  $ docfd --index-only --open-with pdf:detached='okular {page_num}'
  Initializing in-memory index
  $ docfd --index-only --open-with pdf:detached='okular {line_num}'
  error: failed to parse pdf:detached=okular {line_num}, line_num not available
  [1]
  $ docfd --index-only --open-with pdf:detached='okular {search_word}'
  Initializing in-memory index

Pandoc supported extensions parsing test, terminal launch mode:
  $ docfd --index-only --open-with odt:terminal='xdg-open {path}'
  Initializing in-memory index
  $ docfd --index-only --open-with odt:terminal='xdg-open {page_num}'
  error: failed to parse odt:terminal=xdg-open {page_num}, page_num not available
  [1]
  $ docfd --index-only --open-with odt:terminal='xdg-open {line_num}'
  Initializing in-memory index
  $ docfd --index-only --open-with odt:terminal='xdg-open {search_word}'
  error: failed to parse odt:terminal=xdg-open {search_word}, search_word not available
  [1]

Pandoc supported extensions parsing test, detached launch mode:
  $ docfd --index-only --open-with odt:detached='xdg-open {path}'
  Initializing in-memory index
  $ docfd --index-only --open-with odt:detached='xdg-open {page_num}'
  error: failed to parse odt:detached=xdg-open {page_num}, page_num not available
  [1]
  $ docfd --index-only --open-with odt:detached='xdg-open {line_num}'
  Initializing in-memory index
  $ docfd --index-only --open-with odt:detached='xdg-open {search_word}'
  error: failed to parse odt:detached=xdg-open {search_word}, search_word not available
  [1]

Text parsing test, terminal launch mode:
  $ docfd --index-only --open-with txt:terminal='nano {path}'
  Initializing in-memory index
  $ docfd --index-only --open-with txt:terminal='nano {page_num}'
  error: failed to parse txt:terminal=nano {page_num}, page_num not available
  [1]
  $ docfd --index-only --open-with txt:terminal='nano {line_num}'
  Initializing in-memory index
  $ docfd --index-only --open-with txt:terminal='nano {search_word}'
  error: failed to parse txt:terminal=nano {search_word}, search_word not available
  [1]

Text parsing test, detached launch mode:
  $ docfd --index-only --open-with txt:detached='nano {path}'
  Initializing in-memory index
  $ docfd --index-only --open-with txt:detached='nano {page_num}'
  error: failed to parse txt:detached=nano {page_num}, page_num not available
  [1]
  $ docfd --index-only --open-with txt:detached='nano {line_num}'
  Initializing in-memory index
  $ docfd --index-only --open-with txt:detached='nano {search_word}'
  error: failed to parse txt:detached=nano {search_word}, search_word not available
  [1]

Unrecognized extensions parsing test, terminal launch mode:
  $ docfd --index-only --open-with abc:terminal='nano {path}'
  Initializing in-memory index
  $ docfd --index-only --open-with abc:terminal='nano {page_num}'
  error: failed to parse abc:terminal=nano {page_num}, page_num not available
  [1]
  $ docfd --index-only --open-with abc:terminal='nano {line_num}'
  Initializing in-memory index
  $ docfd --index-only --open-with abc:terminal='nano {search_word}'
  error: failed to parse abc:terminal=nano {search_word}, search_word not available
  [1]

Unrecognized extensions parsing test, detached launch mode:
  $ docfd --index-only --open-with abc:detached='nano {path}'
  Initializing in-memory index
  $ docfd --index-only --open-with abc:detached='nano {page_num}'
  error: failed to parse abc:detached=nano {page_num}, page_num not available
  [1]
  $ docfd --index-only --open-with abc:detached='nano {line_num}'
  Initializing in-memory index
  $ docfd --index-only --open-with abc:detached='nano {search_word}'
  error: failed to parse abc:detached=nano {search_word}, search_word not available
  [1]
