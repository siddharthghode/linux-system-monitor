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
