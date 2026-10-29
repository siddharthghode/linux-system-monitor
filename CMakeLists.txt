cmake_minimum_required(VERSION 3.20)

project(LinuxSystemMonitor
    VERSION 1.0.0
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_library(system_info
    src/memory.cpp
)

target_include_directories(system_info
    PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_compile_options(system_info
    PRIVATE -Wall -Wextra -Wpedantic
)

add_executable(system-monitor
    src/main.cpp
    src/cpu.cpp
    src/uptime.cpp
    src/processes.cpp
)

target_link_libraries(system-monitor PRIVATE system_info)

target_compile_options(system-monitor
    PRIVATE -Wall -Wextra -Wpedantic
)

option(ENABLE_ASAN "Enable AddressSanitizer" OFF)

if(ENABLE_ASAN)
    target_compile_options(system_info PRIVATE
        -fsanitize=address -fno-omit-frame-pointer
    )
    target_link_options(system_info PRIVATE -fsanitize=address)

    target_compile_options(system-monitor PRIVATE
        -fsanitize=address -fno-omit-frame-pointer
    )
    target_link_options(system-monitor PRIVATE -fsanitize=address)
endif()
