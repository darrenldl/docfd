# TUI internals

## Component tree

RoCo = Rerender on Change of

Root (RoCo: UI mode)

- Single file view (document to use is passed as argument, then stored in a dependency tracking variable)
  - Top pane (RoCo: document, index of search result selected)
    - Content view
    - Search result list
  - Bottom pane
    - Status bar (RoCo: input mode)
    - Key binding info (RoCo: input mode)
    - Search bar
      - Label (RoCo: input mode)
      - Edit field

- Multi file view
  - Top pane (RoCo: documents, index of document selected)
    - Document list
    - Right pane (RoCo: index of search result selected)
      - Content view
      - Search result list
  - Bottom pane
    - Status bar (RoCo: input mode, index of document selected)
    - Key binding info (RoCo: input mode)
    - Search bar
