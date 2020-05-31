project(elby-parser)

cmake_minimum_required(VERSION 3.16)

# Definitions
set(LIBRARY_TARGET "elby-parser")
set(TEST_TARGET "${LIBRARY_TARGET}_test")
set(INCLUDE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/include" "${CMAKE_CURRENT_SOURCE_DIR}/include/elby/parser" )
set(SOURCE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/src")
set(TEST_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/test")

set(SOURCES
        ${SOURCE_DIRECTORY}/lex.c
        ${SOURCE_DIRECTORY}/parser.c
        ${SOURCE_DIRECTORY}/token.c)

set(HEADERS
        ${INCLUDE_DIRECTORY}/lex.h
        ${INCLUDE_DIRECTORY}/parser.h
        ${INCLUDE_DIRECTORY}/token.h)

# Library Target
add_library (${LIBRARY_TARGET} ${SOURCES} ${HEADERS})
target_include_directories(${LIBRARY_TARGET} PUBLIC "${INCLUDE_DIRECTORY}")

# Test Target
enable_testing()
add_executable(${TEST_TARGET}
    "${TEST_DIRECTORY}/main.c"
    )

target_link_libraries(${TEST_TARGET} PUBLIC ${LIBRARY_TARGET} elby-utils)
target_include_directories(${TEST_TARGET} PUBLIC
        "${INCLUDE_DIRECTORY}"
        "${CMAKE_CURRENT_SOURCE_DIR}/../utils/include")

