qt6 = import('qt6')
qt_deps = dependency('qt6', modules: ['Core', 'Gui', 'Qml', 'Quick', 'DBus', 'Sql'])
gio_dep = dependency('gio-2.0')

layershell_dep = dependency('LayerShellQt', method: 'cmake', modules: ['LayerShellQt::Interface'], required: false)
if not layershell_dep.found()
  cpp = meson.get_compiler('cpp')
  ls_lib = cpp.find_library('LayerShellQt', required: true)
  layershell_dep = declare_dependency(dependencies: ls_lib)
endif

subdir('src')