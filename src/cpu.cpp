#include "system_info.hpp"

#include <fstream>
#include <sstream>
#include <stdexcept>
#include <string>

CpuTimes read_cpu_times(const std::string& path)
{
    std::ifstream file(path);

    if (!file) {
        throw std::runtime_error(
            "Unable to open CPU statistics: " + path
        );
    }

    std::string line;
    std::getline(file, line);

    std::istringstream stream(line);
    std::string label;

    CpuTimes result{};
    std::uint64_t user{}, nice{}, system{}, idle{}, iowait{};
    std::uint64_t irq{}, softirq{}, steal{}, guest{}, guest_nice{};

    if (!(stream >> label >> user >> nice >> system >> idle
                 >> iowait >> irq >> softirq >> steal)) {
        throw std::runtime_error("Invalid CPU statistics");
    }

    // Guest counters are already included in user and nice.
    (void)guest;
    (void)guest_nice;

    result.idle = idle + iowait;
    result.total = user + nice + system + idle + iowait
                 + irq + softirq + steal;

    if (label != "cpu") {
        throw std::runtime_error(
            "Aggregate CPU statistics not found"
        );
    }

    return result;
}

double calculate_cpu_usage(
    const CpuTimes& previous,
    const CpuTimes& current)
{
    if (current.total <= previous.total) {
        return 0.0;
    }

    const auto total_delta = current.total - previous.total;

    const auto idle_delta =
        current.idle >= previous.idle
            ? current.idle - previous.idle
            : 0;

    if (idle_delta > total_delta) {
        return 0.0;
    }

    const double busy =
        static_cast<double>(total_delta - idle_delta);

    return (busy / static_cast<double>(total_delta)) * 100.0;
}
