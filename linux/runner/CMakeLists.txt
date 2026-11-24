cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES C CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "dc/dc_plugin.c"
  "dc/dc_scanner.c"
  "dc/bluez_ble.c"
  "${CMAKE_SOURCE_DIR}/../native/pandive_dc_core.c"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the application ID.
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# Add dependency libraries. Add any application-specific dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Ordenador de buceo: núcleo común (native/) + libdivecomputer estática
# (linux/ldc/, generada con `make ldc-linux`; headers compartidos con Android).
target_include_directories(${BINARY_NAME} PRIVATE
  "${CMAKE_SOURCE_DIR}/../native"
  "${CMAKE_SOURCE_DIR}/../android/app/src/main/cpp/include")
target_link_libraries(${BINARY_NAME} PRIVATE
  "${CMAKE_SOURCE_DIR}/ldc/libdivecomputer.a" m)
