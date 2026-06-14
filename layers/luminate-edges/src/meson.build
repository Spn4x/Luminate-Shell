processed_files = qt6.preprocess(
  moc_headers: [
    '../process/NotificationBackend.h',
    '../process/ScreenshotCanvas.h',
    '../process/LauncherBackend.h',
    '../process/TopbarBackend.h',
    '../process/SystrayBackend.h',
    '../process/AudioBackend.h'
  ],
  qresources: 'resources.qrc'
)

src_files = [
  'main.cpp',
  '../process/NotificationBackend.cpp',
  '../process/ScreenshotCanvas.cpp',
  '../process/LauncherBackend.cpp',
  '../process/TopbarBackend.cpp',
  '../process/SystrayBackend.cpp',
  '../process/AudioBackend.cpp',
  processed_files
]

executable('luminate-edges',
  src_files,
  dependencies: [qt_deps, layershell_dep, gio_dep],
  install: true,
  install_dir: get_option('bindir')
)