cmake_minimum_required(VERSION 3.22)
project(pandive_dc C)

# Prebuilt libdivecomputer (jniLibs/<ABI>/libdivecomputer.so),
# cross-compiled with scripts/build-libdivecomputer-android.sh.
add_library(divecomputer SHARED IMPORTED)
set_target_properties(divecomputer PROPERTIES
    IMPORTED_LOCATION
    ${CMAKE_CURRENT_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libdivecomputer.so)

# Core shared with the Linux app (native/) + JNI adapter.
set(PANDIVE_NATIVE ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../native)
add_library(pandive_dc SHARED pandive_dc.c ${PANDIVE_NATIVE}/pandive_dc_core.c)

target_include_directories(pandive_dc PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include ${PANDIVE_NATIVE})
target_link_libraries(pandive_dc divecomputer log)
