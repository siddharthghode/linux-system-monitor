#ifndef SYSTEM_INFO_HPP
#define SYSTEM_INFO_HPP

#include <cstdint>
#include <string>
#include <vector>

struct MemoryInfo {
    std::uint64_t total_kb{};
    std::uint64_t available_kb{};
    std::uint64_t used_kb{};
};

MemoryInfo read_memory_info(
    const std::string& path = "/proc/meminfo"
);


struct CpuTimes {
    std::uint64_t idle{};
    std::uint64_t total{};
};

CpuTimes read_cpu_times(
    const std::string& path = "/proc/stat"
);

double calculate_cpu_usage(
    const CpuTimes& previous,
    const CpuTimes& current
);


double read_uptime_seconds(
    const std::string& path = "/proc/uptime"
);


struct ProcessInfo {
    int pid{};
    std::string name;
};

std::vector<ProcessInfo> read_processes(
    const std::string& path = "/proc"
);

#endif
