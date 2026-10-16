def install(studio):
    if getattr(studio, "editor", None) is None:
        return None
    from studio.ux.qt import install as install_ux
    return install_ux(studio)
