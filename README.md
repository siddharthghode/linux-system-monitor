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
