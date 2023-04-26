open Ui_base

let top_pane
(ctx : ctx Lwd.var)
  : Nottui.ui Lwd.t =
  Nottui_widgets.h_pane
    (Document_list.f ctx)
    (Nottui_widgets.v_pane
       (Content_view.f ctx)
       (Content_search_results.f ctx))
