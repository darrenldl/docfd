let main
    ~(input_mode : Ui_components.input_mode Lwd.t)
    ~(ui_mode : Ui_components.ui_mode Lwd.t)
    ~(documents : Nottui.ui Lwd.t)
    ~(document_selected : Nottui.ui Lwd.t)
  : Nottui.ui Lwd.t =
  Nottui_widgets.h_pane
    (left_pane ())
    (Nottui_widgets.v_pane
       (file_view ())
       content_search_results)
