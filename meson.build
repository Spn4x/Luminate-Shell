project('luminate', 'cpp',
  version: '0.2.0',
  default_options: [
    'warning_level=2',
    'cpp_std=c++17',
    'buildtype=release'
  ]
)

# 1. Enter the src directory (compiles main CLI and Daemons)
subdir('src')

# 2. Enter the layers directory (compiles the visual Shells)
subdir('layers/handsight')
subdir('layers/luminate-edges')
subdir('layers/surfacedesk-qml')