qt6 = import('qt6')

qt_deps = dependency('qt6', modules: ['Core', 'Gui', 'Qml', 'Quick', 'DBus'])

cpp = meson.get_compiler('cpp')

layershell_dep = dependency('LayerShellQt', required: false)

if not layershell_dep.found()
  layershell_dep = dependency('LayerShellQt', method: 'cmake', modules: ['LayerShellQt::Interface'], required: false)
endif

if not layershell_dep.found()
  ls_lib = cpp.find_library('LayerShellQt', required: true)
  layershell_dep = declare_dependency(dependencies: ls_lib)
endif

processed_files = qt6.preprocess(
  moc_headers: 'process/NotificationBackend.h',
  qresources: 'resources.qrc'
)

src_files = [
  'process/main.cpp',
  'process/NotificationBackend.cpp',
  processed_files
]

executable('luminate-handsight',
  src_files,
  dependencies: [qt_deps, layershell_dep],
  install: true,
  install_dir: get_option('bindir')
)