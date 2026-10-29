#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="${1:-$HOME/sppu/git/linux-system-monitor}"

echo "======================================"
echo " Linux System Monitor - CPU Update"
echo "======================================"

# Validate project directory
if [[ ! -d "$PROJECT_DIR/include" ||
      ! -f "$PROJECT_DIR/include/system_info.hpp" ||
      ! -f "$PROJECT_DIR/CMakeLists.txt" ]]; then
    echo "ERROR: Existing project not found at:"
    echo "$PROJECT_DIR"
    echo "Usage: $0 /path/to/linux-system-monitor"
    exit 1
fi

for tool in python3 g++ ; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: Missing required tool: $tool"
        exit 1
    fi
done

cd "$PROJECT_DIR"

# 1. Add CPU declarations to the existing header.
# Preserve all existing memory declarations and include statements.
python3 - <<'PY'
from pathlib import Path

header = Path("include/system_info.hpp")
content = header.read_text()

if "struct CpuTimes" in content:
    print("CPU declarations already exist; header unchanged.")
else:
    marker = "#endif"

    if marker not in content:
        raise SystemExit("ERROR: Header guard #endif not found.")

    declarations = """
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

"""

    position = content.rfind(marker)
    content = content[:position] + declarations + content[position:]
    header.write_text(content)
    print("Added CpuTimes declarations to system_info.hpp.")
PY

# 2. Replace src/cpu.cpp.
cat > src/cpu.cpp <<'EOF'
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
EOF

# 3. Create the temporary CPU test.
cat > cpu_check.cpp <<'EOF'
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
EOF

# 4. Compile the temporary test.
echo
echo "========== Compiling CPU test =========="

g++ -std=c++17 -Wall -Wextra -Wpedantic \
    -Iinclude cpu_check.cpp src/cpu.cpp \
    -o cpu_check

echo "Compilation successful."

# 5. Run the test.
echo
echo "========== Running CPU test =========="
./cpu_check

# 6. Build the complete existing CMake project.
echo
echo "========== Building CMake project =========="
cmake -S . -B build
cmake --build build --parallel 2

echo
echo "========== Project status =========="
git status --short

echo
echo "SUCCESS: CPU monitoring component added."
echo "Temporary test: $PROJECT_DIR/cpu_check"
echo "Main executable: $PROJECT_DIR/build/system-monitor"
