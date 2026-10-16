def install(studio):
    from studio.backends.qt import install as install_backends
    return install_backends(studio)
