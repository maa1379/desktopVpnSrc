cmake_minimum_required(VERSION 3.10)
set(PROJECT_NAME "flutter_v2ray_client_desktop")
project(${PROJECT_NAME} LANGUAGES C CXX)

# Find GLib dependencies using PkgConfig
find_package(PkgConfig REQUIRED)
pkg_check_modules(GLIB REQUIRED IMPORTED_TARGET glib-2.0)
pkg_check_modules(GOBJECT REQUIRED IMPORTED_TARGET gobject-2.0)

set(PLUGIN_NAME "flutter_v2ray_client_desktop_plugin")

add_library(${PLUGIN_NAME} SHARED
  "flutter_v2ray_client_desktop_plugin.cc"
)

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_STANDARD 14
  CXX_STANDARD_REQUIRED YES
)

apply_standard_settings(${PLUGIN_NAME})

target_include_directories(${PLUGIN_NAME} PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter
  PkgConfig::GLIB
  PkgConfig::GOBJECT
)

target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Common files for all architectures
set(common_libraries
  "${CMAKE_CURRENT_SOURCE_DIR}/resources/tun.json"
  "${CMAKE_CURRENT_SOURCE_DIR}/resources/cache.db"
  "${CMAKE_CURRENT_SOURCE_DIR}/resources/geoip.dat"
  "${CMAKE_CURRENT_SOURCE_DIR}/resources/geosite.dat"
)

# List of absolute paths to libraries that should be bundled with the plugin (if any).
# This is consumed by the runner's generated_plugins.cmake.
if (CMAKE_SYSTEM_PROCESSOR STREQUAL "x86_64" OR CMAKE_SYSTEM_PROCESSOR STREQUAL "AMD64")
    message("[FLUTTER_V2RAY] Detected architecture: x86_64")
    set(${PROJECT_NAME}_bundled_libraries
      "${CMAKE_CURRENT_SOURCE_DIR}/resources/64/xray"
      "${CMAKE_CURRENT_SOURCE_DIR}/resources/64/sing-box"
      "${CMAKE_CURRENT_SOURCE_DIR}/resources/64/xray-knife"
      ${common_libraries}
            PARENT_SCOPE
    )
    # Ensure executables keep the execute bit when installed, and place beside app
    install(PROGRAMS "${CMAKE_CURRENT_SOURCE_DIR}/resources/64/xray" "${CMAKE_CURRENT_SOURCE_DIR}/resources/64/sing-box" "${CMAKE_CURRENT_SOURCE_DIR}/resources/64/xray-knife"
      DESTINATION .
      COMPONENT Runtime
    )
elseif (CMAKE_SYSTEM_PROCESSOR STREQUAL "arm64" OR CMAKE_SYSTEM_PROCESSOR STREQUAL "aarch64" OR CMAKE_SYSTEM_PROCESSOR STREQUAL "ARM64")
    message("[FLUTTER_V2RAY] Detected architecture: arm64")
    set(${PROJECT_NAME}_bundled_libraries
      "${CMAKE_CURRENT_SOURCE_DIR}/resources/arm64/xray"
      "${CMAKE_CURRENT_SOURCE_DIR}/resources/arm64/sing-box"
      "${CMAKE_CURRENT_SOURCE_DIR}/resources/arm64/xray-knife"
      ${common_libraries}
            PARENT_SCOPE
    )
    # Ensure executables keep the execute bit when installed, and place beside app
    install(PROGRAMS "${CMAKE_CURRENT_SOURCE_DIR}/resources/arm64/xray" "${CMAKE_CURRENT_SOURCE_DIR}/resources/arm64/sing-box" "${CMAKE_CURRENT_SOURCE_DIR}/resources/arm64/xray-knife"
      DESTINATION .
      COMPONENT Runtime
    )
else()
    message("[FLUTTER_V2RAY] Detected architecture: other (${CMAKE_SYSTEM_PROCESSOR})")
    set(${PROJECT_NAME}_bundled_libraries
      "${CMAKE_CURRENT_SOURCE_DIR}/resources/64/xray"
      "${CMAKE_CURRENT_SOURCE_DIR}/resources/64/sing-box"
      "${CMAKE_CURRENT_SOURCE_DIR}/resources/64/xray-knife"
      ${common_libraries}
            PARENT_SCOPE
    )
    # Ensure executables keep the execute bit when installed, and place beside app
    install(PROGRAMS "${CMAKE_CURRENT_SOURCE_DIR}/resources/64/xray" "${CMAKE_CURRENT_SOURCE_DIR}/resources/64/sing-box" "${CMAKE_CURRENT_SOURCE_DIR}/resources/64/xray-knife"
      DESTINATION .
      COMPONENT Runtime
    )
endif()

# Install the srss directory and other resource files beside the app
install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/resources/srss"
  DESTINATION .
  COMPONENT Runtime
)
install(FILES
  "${CMAKE_CURRENT_SOURCE_DIR}/resources/tun.json"
  "${CMAKE_CURRENT_SOURCE_DIR}/resources/cache.db"
  "${CMAKE_CURRENT_SOURCE_DIR}/resources/geoip.dat"
  "${CMAKE_CURRENT_SOURCE_DIR}/resources/geosite.dat"
  DESTINATION .
  COMPONENT Runtime
)
