cmake_minimum_required(VERSION 3.16)

project(elby
        DESCRIPTION "An embeddable language with enhanced typing"
        LANGUAGES C)

# Standards
set(CMAKE_C_STANDARD 99)
set(CMAKE_C_FLAGS  "${CMAKE_C_FLAGS} -Wall -Werror -Wno-unused-variable -Wno-unused-function -Wno-switch")

# Include the sub projects
add_subdirectory(src)

