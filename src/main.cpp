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
