qt6 = import('qt6')

# ---------------------------------------------------
# 1. Resolve Shared Qt6 Modules
# ---------------------------------------------------
# Core DBus functionality needed by almost everything
qt_core_deps = dependency('qt6', modules: ['Core', 'DBus'])

# Sql needed for Insightd, Notifyd, and Launcherd history
qt_sql_deps  = dependency('qt6', modules: ['Core', 'DBus', 'Sql'])

# Network needed for Mediad to fetch lyrics from HTTP APIs
qt_net_deps  = dependency('qt6', modules: ['Core', 'DBus', 'Network'])

# Qml module includes QJSEngine, used by Launcherd for math evaluation
qt_qml_deps  = dependency('qt6', modules: ['Core', 'DBus', 'Sql', 'Qml'])

# ---------------------------------------------------
# 2. Resolve External C Dependencies
# ---------------------------------------------------
# Needed for Pipewire audio/video hardware node monitoring
pipewire_dep = dependency('libpipewire-0.3')

# Needed by Launcherd to index desktop applications
gio_dep = dependency('gio-2.0')

# ---------------------------------------------------
# 3. Define and Build Daemons
# ---------------------------------------------------
daemons = [
  {
    'name': 'luminate-privacyd',
    'src': 'privacyd.cpp',
    'deps': [qt_core_deps, pipewire_dep]
  },
  {
    'name': 'luminate-insightd',
    'src': 'insightd.cpp',
    'deps': [qt_sql_deps]
  },
  {
    'name': 'luminate-notifyd',
    'src': 'notifyd.cpp',
    'deps': [qt_sql_deps]
  },
  {
    'name': 'luminate-widgetd',
    'src': 'widgetd.cpp',
    'deps': [qt_core_deps]
  },
  {
    'name': 'luminate-osdd',
    'src': 'osdd.cpp',
    'deps': [qt_core_deps]
  },
  {
    'name': 'luminate-mediad',
    'src': 'mediad.cpp',
    'deps': [qt_net_deps]
  },
  {
    'name': 'luminate-launcherd',
    'src': 'launcherd.cpp',
    'deps': [qt_qml_deps, gio_dep]
  }
]

# Iterate through the list, pre-process the inline MOC classes, and compile
foreach d : daemons
  # This replaces "automoc" by explicitly telling the Qt6 compiler module 
  # to parse the inline Q_OBJECT macros from the .cpp source files.
  processed = qt6.preprocess(
    moc_sources: d['src']
  )

  executable(d['name'],
    d['src'], processed,
    dependencies: d['deps'],
    install: true,
    install_dir: get_option('bindir')
  )
endforeach