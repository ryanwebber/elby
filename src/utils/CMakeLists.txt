project(elby-utils)

# Definitions
set(LIBRARY_TARGET "elby-utils")
set(TEST_TARGET "${LIBRARY_TARGET}_test")
set(INCLUDE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/include/elby/utils")
set(SOURCE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/src")
set(TEST_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/test")

set(SOURCES
        "${SOURCE_DIRECTORY}/tstree.c"
        "${SOURCE_DIRECTORY}/vector.c"
        )

set(HEADERS
        "${INCLUDE_DIRECTORY}/tstree.h"
        "${INCLUDE_DIRECTORY}/vector.h"
        )

# Library Target
add_library (${LIBRARY_TARGET} ${SOURCES} ${HEADERS})
target_include_directories(${LIBRARY_TARGET} PUBLIC "${INCLUDE_DIRECTORY}")

# Test Target
enable_testing()
add_executable(${TEST_TARGET}
    "${TEST_DIRECTORY}/main.c"
    )

target_link_libraries(${TEST_TARGET} PUBLIC ${LIBRARY_TARGET})
target_include_directories(${TEST_TARGET} PUBLIC "${INCLUDE_DIRECTORY}")

