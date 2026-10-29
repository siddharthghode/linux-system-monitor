#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="${1:-$HOME/sppu/git/linux-system-monitor}"

echo "========================================"
echo " Linux System Monitor - Project Setup"
echo "========================================"
echo "Project directory: $PROJECT_DIR"

# Check required tools
for tool in g++ cmake git; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: $tool is not installed."
        echo "Install it using: sudo apt install build-essential cmake git"
        exit 1
    fi
done

# Create project structure
mkdir -p "$PROJECT_DIR"/{include,src,tests}
cd "$PROJECT_DIR"

# Header
cat > include/system_info.hpp <<'EOF'
#ifndef SYSTEM_INFO_HPP
#define SYSTEM_INFO_HPP

#include <cstdint>
#include <string>

struct MemoryInfo {
    std::uint64_t total_kb{};
    std::uint64_t available_kb{};
    std::uint64_t used_kb{};
};

MemoryInfo read_memory_info(
    const std::string& path = "/proc/meminfo"
);

#endif
EOF

# Memory implementation
cat > src/memory.cpp <<'EOF'
#include "system_info.hpp"

#include <fstream>
#include <sstream>
#include <stdexcept>
#include <string>

MemoryInfo read_memory_info(const std::string& path)
{
    std::ifstream file(path);

    if (!file) {
        throw std::runtime_error(
            "Unable to open memory information: " + path
        );
    }

    MemoryInfo info{};
    std::string line;

    while (std::getline(file, line)) {
        std::istringstream stream(line);
        std::string key;
        std::uint64_t value{};

        if (!(stream >> key >> value)) {
            continue;
        }

        if (key == "MemTotal:") {
            info.total_kb = value;
        } else if (key == "MemAvailable:") {
            info.available_kb = value;
        }
    }

    if (info.total_kb == 0 ||
        info.available_kb > info.total_kb) {
        throw std::runtime_error("Invalid memory information");
    }

    info.used_kb = info.total_kb - info.available_kb;
    return info;
}
EOF

# Working command-line application
cat > src/main.cpp <<'EOF'
#include "system_info.hpp"

#include <exception>
#include <iomanip>
#include <iostream>

int main()
{
    try {
        const MemoryInfo memory = read_memory_info();

        constexpr double KB_PER_GB = 1024.0 * 1024.0;

        std::cout << "\n=== Linux System Monitor ===\n\n";
        std::cout << std::fixed << std::setprecision(2);

        std::cout << "Total memory:     "
                  << memory.total_kb / KB_PER_GB << " GB\n";

        std::cout << "Available memory: "
                  << memory.available_kb / KB_PER_GB << " GB\n";

        std::cout << "Estimated used:   "
                  << memory.used_kb / KB_PER_GB << " GB\n";

        const double usage = memory.total_kb
            ? 100.0 * memory.used_kb / memory.total_kb
            : 0.0;

        std::cout << "Memory usage:     "
                  << usage << "%\n\n";

        return 0;
    } catch (const std::exception& error) {
        std::cerr << "Error: " << error.what() << '\n';
        return 1;
    }
}
EOF

# Future components: placeholders for later implementation
cat > src/cpu.cpp <<'EOF'
// TODO: Implement CPU statistics using /proc/stat.
EOF

cat > src/uptime.cpp <<'EOF'
// TODO: Implement system uptime using /proc/uptime.
EOF

cat > src/processes.cpp <<'EOF'
// TODO: Implement process enumeration using /proc.
EOF

# Initial test placeholder
cat > tests/test_system_info.cpp <<'EOF'
// TODO: Add automated tests for read_memory_info().
EOF

# CMake configuration
cat > CMakeLists.txt <<'EOF'
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
EOF

# README
cat > README.md <<'EOF'
# Linux System Monitor

A C++17 Linux system-monitoring project using Linux procfs.

## Current features

- Read total and available memory from /proc/meminfo.
- Calculate estimated memory usage.
- Display memory usage in GB and percentage.

## Build

cmake -S . -B build
cmake --build build

## Run

./build/system-monitor

## AddressSanitizer build

cmake -S . -B build-asan -DENABLE_ASAN=ON
cmake --build build-asan
./build-asan/system-monitor

## Planned features

- CPU usage from /proc/stat.
- System uptime from /proc/uptime.
- Process enumeration from /proc.
- Automated unit tests.
EOF

# Initialize Git only when needed
if [ ! -d .git ]; then
    git init
fi

echo
echo "========== Compiler =========="
g++ --version | head -n 1

echo
echo "========== CMake =========="
cmake --version | head -n 1

echo
echo "========== Configure =========="
cmake -S . -B build

echo
echo "========== Build =========="
cmake --build build --parallel 2

echo
echo "========== Run application =========="
./build/system-monitor

echo
echo "========== CMakeLists.txt =========="
cat CMakeLists.txt

echo
echo "========== Git status =========="
git status --short

echo
echo "SUCCESS: Initial project created and built."
echo "Project: $PROJECT_DIR"
echo "Executable: $PROJECT_DIR/build/system-monitor"
