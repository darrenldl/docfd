let main
    ~(documents : Nottui.ui Lwd.t)
    ~(document_selected : Nottui.ui Lwd.t)
  : Nottui.ui Lwd.t =
  Nottui_widgets.v_pane
    (file_view ())
    content_search_results
