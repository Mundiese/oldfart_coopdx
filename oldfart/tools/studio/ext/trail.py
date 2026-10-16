def install(studio):
    from studio.toolbox import trail as T
    from studio.toolbox.qt import paint
    ed = getattr(studio, "editor", None)
    ctx = studio.ctx
    state = {"layer": None}
    def keys():
        if ed is None:
            return []
        doc = ed.session.doc
        out = []
        try:
            out.append(doc.to_layout().get("key"))
        except Exception:
            pass
        rest = getattr(doc, "rest", {}) or {}
        out.append(rest.get("key"))
        try:
            from studio.editor import engine
            out.append(engine.key_for(rest.get("name") or ""))
        except Exception:
            pass
        return [k for k in out if k and k != "generated"]
    def toggle(on):
        if not on:
            state["layer"] = None
            ctx.redraw()
            return
        pts, key, path = T.find(keys())
        state["layer"] = T.layer(pts or [])
        if ed is not None:
            if pts:
                ed.hint("Mario's trail: %d points from the last play of %s" % (len(pts), key))
            else:
                ed.hint(state["layer"].note)
        ctx.redraw()
    def painter(view, p, w, h):
        lay = state["layer"]
        if lay is not None and len(lay):
            paint.paint_layer(p, view, lay, w, h)
    ctx.painters.append(painter)
    win = getattr(studio, "window", None)
    if win is not None and hasattr(win, "add_action"):
        win.add_action("view.trail", toggle, "Mario's trail (last play)", checkable=True,
                       group="View")
    studio.trail = state
    return state
