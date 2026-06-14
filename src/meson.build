qt6 = import('qt6')

qt_cli_deps = dependency('qt6', modules: ['Core', 'DBus'])

# Compile the master session manager and CLI
executable('luminate-shell',
  'main.cpp',
  dependencies: [qt_cli_deps],
  install: true,
  install_dir: get_option('bindir')
)

subdir('daemons')