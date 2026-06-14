qt6 = import('qt6')
qt_deps = dependency('qt6', modules: ['Core', 'Gui', 'Qml', 'Quick', 'WaylandClient', 'DBus', 'Sql'])

cpp = meson.get_compiler('cpp')
layershell_dep = dependency('LayerShellQt', method: 'cmake', modules: ['LayerShellQt::Interface'], required: false)
if not layershell_dep.found()
  ls_lib = cpp.find_library('LayerShellQt', required: true)
  layershell_dep = declare_dependency(dependencies: ls_lib)
endif

# Link the standard system PAM library
pam_dep = cpp.find_library('pam', required: true)

# Qt Preprocessing (MOC & QRC Compilation)
processed_files = qt6.preprocess(
  moc_headers: [
    'process/WallpaperBackend.h', 
    'process/Storage.h'
  ],
  qresources: 'resources.qrc'
)

sources = [
  'process/main.cpp',
  'process/WallpaperBackend.cpp',
  'process/Storage.cpp',
  processed_files
]

executable('luminate-surfacedesk',
  sources,
  dependencies: [qt_deps, layershell_dep, pam_dep],
  install: true,
  install_dir: get_option('bindir')
)