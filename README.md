# Linux System Monitor

A Linux system-monitoring utility written in **C++17** that reads system information from Linux's `/proc` virtual filesystem.

## Features

- **CPU monitoring:** Estimates CPU utilization using successive readings from `/proc/stat`.
- **Memory monitoring:** Reads total and available memory from `/proc/meminfo` and calculates estimated memory usage.
- **System uptime:** Reads uptime information from `/proc/uptime`.
- **Process enumeration:** Lists process IDs and names by inspecting `/proc` entries.
- **Unit testing:** Uses Google Test to validate parsing, calculations, invalid input handling, and missing-file scenarios.
- **Static analysis:** Supports Clang-Tidy.
- **Memory-error checking:** Supports AddressSanitizer builds.

## Tech Stack

- C++17
- Linux procfs
- CMake
- Google Test
- Clang-Tidy
- AddressSanitizer

## Project Structure

```text
linux-system-monitor/
├── CMakeLists.txt
├── include/
│   └── system_info.hpp
├── src/
│   ├── main.cpp
│   ├── cpu.cpp
│   ├── memory.cpp
│   ├── uptime.cpp
│   └── processes.cpp
├── tests/
│   └── test_system_info.cpp
├── .gitignore
└── README.md
```

## Build

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build --parallel
```

## Run

```bash
./build/system-monitor
```

The intended integrated program displays CPU usage, total/used/available RAM, system uptime, and a sample of the running processes.

## Run Tests

```bash
ctest --test-dir build --output-on-failure
```

The current test suite contains 11 tests covering CPU statistics, memory parsing, uptime parsing, process-name parsing, and error cases.

## AddressSanitizer

Configure and build with AddressSanitizer enabled:

```bash
cmake -S . -B build-asan \
    -DCMAKE_BUILD_TYPE=Debug \
    -DENABLE_ASAN=ON

cmake --build build-asan --parallel
./build-asan/system-monitor
```

## Static Analysis

Generate the compilation database and run Clang-Tidy:

```bash
cmake -S . -B build \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON

clang-tidy -p build \
    src/main.cpp \
    src/cpu.cpp \
    src/memory.cpp \
    src/uptime.cpp \
    src/processes.cpp
```

## Platform

Designed for Linux systems with a mounted `/proc` filesystem.

## Learning Objectives

This project demonstrates Linux systems programming fundamentals, C++ development, filesystem-based system inspection, parsing system statistics, modular code organization, unit testing, and static-analysis workflows.
