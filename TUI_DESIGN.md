# TUI internals

## Component tree

RoCo = Rerender on Change of

Root (RoCo: UI mode)

- Single file view (RoCo: document selected)
  - Top pane (RoCo: document selected, index of search result selected)
    - Content view
    - Search result list (index of search result var is passed for mouse handler)
  - Bottom pane (RoCo: input mode)
    - Status bar
    - Key binding info
    - Search bar

- Multi file view (RoCo: documents)
  - Top pane (RoCo: index of document selected)
    - Document list
    - Right pane (RoCo: index of search result selected)
      - Content view
      - Search result list (index of search result var is passed for mouse handler)
  - Bottom pane (RoCo: input mode)
    - Status bar (RoCo: index of document selected)
    - Key binding info
    - Search bar
