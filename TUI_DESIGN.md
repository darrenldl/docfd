# TUI internals

## Component tree

RoCo = Rerender on Change of

Root (RoCo: UI mode)

- Single file view (RoCo: document selected)
  - Top pane (RoCo: document selected, index of search result selected)
    - Content view
    - Search result list
  - Bottom pane (RoCo: input mode)
    - Status bar
    - Key binding info
    - Search bar
      - Label
      - Edit field

- Multi file view (RoCo: documents)
  - Top pane (RoCo: index of document selected)
    - Document list
    - Right pane (RoCo: index of search result selected)
      - Content view
      - Search result list
  - Bottom pane
    - Status bar (RoCo: input mode, index of document selected)
    - Key binding info (RoCo: input mode)
    - Search bar
      - Label (RoCo: input mode)
      - Edit field
