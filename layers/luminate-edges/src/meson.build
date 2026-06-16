processed_files = qt6.preprocess(
  moc_headers: [
    '../process/NotificationBackend.h',
    '../process/ScreenshotCanvas.h',
    '../process/LauncherBackend.h',
    '../process/TopbarBackend.h',
    '../process/SystrayBackend.h',
    '../process/AudioBackend.h',
    '../process/FanBackend.h',
    '../process/PolkitBackend.h'
  ],
  qresources: 'resources.qrc'
)

sensors_dep = cpp.find_library('sensors', required: true)

src_files = [
  'main.cpp',
  '../process/NotificationBackend.cpp',
  '../process/ScreenshotCanvas.cpp',
  '../process/LauncherBackend.cpp',
  '../process/TopbarBackend.cpp',
  '../process/SystrayBackend.cpp',
  '../process/AudioBackend.cpp',
  '../process/FanBackend.cpp',
  '../process/PolkitBackend.cpp',
  processed_files
]

executable('luminate-edges',
  src_files,
  dependencies: [qt_deps, layershell_dep, gio_dep, sensors_dep],
  install: true,
  install_dir: get_option('bindir')
)