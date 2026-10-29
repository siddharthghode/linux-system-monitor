#include "system_info.hpp"

#include <fstream>
#include <stdexcept>

double read_uptime_seconds(const std::string& path)
{
    std::ifstream file(path);

    if (!file) {
        throw std::runtime_error(
            "Unable to open uptime information: " + path
        );
    }

    double uptime{};
    if (!(file >> uptime) || uptime < 0.0) {
        throw std::runtime_error("Invalid uptime information");
    }

    return uptime;
}
