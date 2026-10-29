#include "system_info.hpp"

#include <chrono>
#include <iostream>
#include <thread>

int main()
{
    try {
        const CpuTimes first = read_cpu_times();

        // Allow counters to advance before taking the second sample.
        std::this_thread::sleep_for(
            std::chrono::milliseconds(500)
        );

        const CpuTimes second = read_cpu_times();

        std::cout << "CPU usage: "
                  << calculate_cpu_usage(first, second)
                  << "%\n";

        return 0;
    } catch (const std::exception& error) {
        std::cerr << "CPU monitoring error: "
                  << error.what() << '\n';
        return 1;
    }
}
