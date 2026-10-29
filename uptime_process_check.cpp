#include "system_info.hpp"

#include <algorithm>
#include <iostream>
#include <stdexcept>

int main()
{
    try {
        const double uptime = read_uptime_seconds();
        const auto processes = read_processes();

        std::cout << "System uptime: "
                  << uptime << " seconds\n";

        std::cout << "Processes found: "
                  << processes.size() << '\n';

        std::cout << "\nFirst 10 processes:\n";

        const auto count = std::min<std::size_t>(
            processes.size(), 10
        );

        for (std::size_t i = 0; i < count; ++i) {
            std::cout << "PID: " << processes[i].pid
                      << " | Name: " << processes[i].name
                      << '\n';
        }

        if (uptime < 0.0) {
            throw std::runtime_error("Unexpected negative uptime");
        }

        return 0;
    } catch (const std::exception& error) {
        std::cerr << "Test failed: "
                  << error.what() << '\n';
        return 1;
    }
}
