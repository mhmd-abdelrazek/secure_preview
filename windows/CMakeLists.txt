cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "secure_preview")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed.
set(PLUGIN_NAME "secure_preview_plugin")

list(APPEND PLUGIN_SOURCES
  "secure_preview_plugin.cpp"
  "secure_preview_plugin.h"
)

add_library(${PLUGIN_NAME} SHARED
  "include/secure_preview/secure_preview_plugin_c_api.h"
  "secure_preview_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin user32 advapi32)

# List of absolute paths to libraries that should be bundled with the plugin.
set(secure_preview_bundled_libraries
  ""
  PARENT_SCOPE
)
