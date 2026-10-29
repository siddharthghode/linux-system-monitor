#include "system_info.hpp"

#include <chrono>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <thread>

int main()
{
    try
    {
        const auto previous = read_cpu_times();

        // Allow CPU counters to change before taking the next sample.
        std::this_thread::sleep_for(std::chrono::milliseconds(1000));

        const auto current = read_cpu_times();
        const auto memory = read_memory_info();
        const double uptime = read_uptime_seconds();
        const auto processes = read_processes();

        const double total_gb = memory.total_kb / 1024.0 / 1024.0;
        const double used_gb = memory.used_kb / 1024.0 / 1024.0;
        const double available_gb =
            memory.available_kb / 1024.0 / 1024.0;

        const auto uptime_hours =
            static_cast<unsigned long long>(uptime / 3600.0);
        const auto uptime_minutes =
            static_cast<unsigned long long>(uptime / 60.0) % 60;
        const auto uptime_seconds =
            static_cast<unsigned long long>(uptime) % 60;

        std::cout << "\n====================================\n"
                  << "       LINUX SYSTEM MONITOR\n"
                  << "====================================\n";

        std::cout << std::fixed << std::setprecision(2);
        std::cout << "CPU Usage       : "
                  << calculate_cpu_usage(previous, current) << "%\n";

        std::cout << "Total RAM       : " << total_gb << " GB\n"
                  << "Used RAM        : " << used_gb << " GB\n"
                  << "Available RAM   : " << available_gb << " GB\n";

        std::cout << "System Uptime   : "
                  << uptime_hours << "h "
                  << uptime_minutes << "m "
                  << uptime_seconds << "s\n";

        std::cout << "Running Processes: "
                  << processes.size() << "\n";

        std::cout << "\n--- Process List (first 15) ---\n";
        std::cout << std::left
                  << std::setw(10) << "PID"
                  << "PROCESS\n";
        std::cout << "------------------------------------\n";

        for (std::size_t i = 0;
             i < processes.size() && i < 15;
             ++i)
        {
            std::cout << std::left
                      << std::setw(10) << processes[i].pid
                      << processes[i].name << '\n';
        }

        std::cout << "====================================\n";
    }
    catch (const std::exception &error)
    {
        std::cerr << "Error: " << error.what() << '\n';
        return 1;
    }

    return 0;
}