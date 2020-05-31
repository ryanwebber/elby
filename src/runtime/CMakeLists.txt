project(elby-runtime)

cmake_minimum_required(VERSION 3.16)

# Definitions
set(LIBRARY_TARGET "elby-runtime")
set(TEST_TARGET "${LIBRARY_TARGET}_test")
set(INCLUDE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/include" "${CMAKE_CURRENT_SOURCE_DIR}/include/elby/runtime" )
set(SOURCE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/src")
set(TEST_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/test")

set(SOURCES
        ${SOURCE_DIRECTORY}/hashtable.c
        ${SOURCE_DIRECTORY}/runtime.c
        ${SOURCE_DIRECTORY}/value.c
        ${SOURCE_DIRECTORY}/vm.c
        )

set(HEADERS
        ${INCLUDE_DIRECTORY}/runtime.h
        )

# Library Target
add_library (${LIBRARY_TARGET} ${SOURCES} ${HEADERS})
target_include_directories(${LIBRARY_TARGET} PUBLIC
        "${INCLUDE_DIRECTORY}"
        "${CMAKE_CURRENT_SOURCE_DIR}/../utils/include")

target_link_libraries(${LIBRARY_TARGET} PUBLIC elby-utils)

# Test Target
enable_testing()
add_executable(${TEST_TARGET}
    "${TEST_DIRECTORY}/main.c"
    )

target_link_libraries(${TEST_TARGET} PUBLIC ${LIBRARY_TARGET})
target_include_directories(${TEST_TARGET} PUBLIC "${INCLUDE_DIRECTORY}")

