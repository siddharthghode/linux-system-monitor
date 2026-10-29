
#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="${1:-$HOME/sppu/git/linux-system-monitor}"

echo "=========================================="
echo " Linux System Monitor - Uptime + Processes"
echo "=========================================="

# Validate the existing project
if [[ ! -f "$PROJECT_DIR/include/system_info.hpp" ||
      ! -f "$PROJECT_DIR/CMakeLists.txt" ]]; then
    echo "ERROR: Existing project not found: $PROJECT_DIR"
    echo "Usage: $0 /path/to/linux-system-monitor"
    exit 1
fi

for tool in python3 g++; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: Required tool not found: $tool"
        exit 1
    fi
done

cd "$PROJECT_DIR"

# 1. Update the header without removing existing declarations.
python3 <<'PY'
from pathlib import Path

header = Path("include/system_info.hpp")
content = header.read_text()

if "#include <vector>" not in content:
    if "#include <string>" not in content:
        raise SystemExit("ERROR: Expected #include <string> in header.")
    content = content.replace(
        "#include <string>",
        "#include <string>\n#include <vector>",
        1
    )

uptime = """
double read_uptime_seconds(
    const std::string& path = "/proc/uptime"
);
"""

processes = """
struct ProcessInfo {
    int pid{};
    std::string name;
};

std::vector<ProcessInfo> read_processes(
    const std::string& path = "/proc"
);
"""

if "read_uptime_seconds" not in content:
    pos = content.rfind("#endif")
    if pos == -1:
        raise SystemExit("ERROR: Header guard #endif not found.")
    content = content[:pos] + uptime + "\n" + content[pos:]

if "struct ProcessInfo" not in content:
    pos = content.rfind("#endif")
    if pos == -1:
        raise SystemExit("ERROR: Header guard #endif not found.")
    content = content[:pos] + processes + "\n" + content[pos:]

header.write_text(content)
print("Updated include/system_info.hpp")
PY

# 2. Implement system uptime.
cat > src/uptime.cpp <<'EOF'
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
EOF

# 3. Implement process enumeration.
cat > src/processes.cpp <<'EOF'
#include "system_info.hpp"

#include <filesystem>
#include <fstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace fs = std::filesystem;

std::vector<ProcessInfo> read_processes(const std::string& path)
{
    std::vector<ProcessInfo> processes;
    std::error_code ec;

    fs::directory_iterator it(path, ec);
    const fs::directory_iterator end;

    if (ec) {
        throw std::runtime_error(
            "Unable to read process directory: " + path
        );
    }

    for (; it != end; it.increment(ec)) {
        if (ec) {
            ec.clear();
            continue;
        }

        const std::string directory =
            it->path().filename().string();

        if (directory.empty() ||
            directory.find_first_not_of("0123456789")
                != std::string::npos) {
            continue;
        }

        try {
            const int pid = std::stoi(directory);
            std::ifstream stat_file(it->path() / "stat");

            if (!stat_file) {
                continue;
            }

            std::string line;
            std::getline(stat_file, line);

            const auto start = line.find('(');
            const auto finish = line.rfind(')');

            if (start == std::string::npos ||
                finish == std::string::npos ||
                finish <= start) {
                continue;
            }

            processes.push_back({
                pid,
                line.substr(start + 1, finish - start - 1)
            });
        } catch (const std::exception&) {
            // A process may exit while /proc is being scanned.
            continue;
        }
    }

    return processes;
}
EOF

# 4. Create a temporary integration test.
cat > uptime_process_check.cpp <<'EOF'
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
EOF

# 5. Compile and run the integration test.
echo
echo "========== Compile uptime/process test =========="

g++ -std=c++17 -Wall -Wextra -Wpedantic \
    -Iinclude \
    uptime_process_check.cpp \
    src/uptime.cpp \
    src/processes.cpp \
    -o uptime_process_check

echo
echo "========== Run uptime/process test =========="
./uptime_process_check

# 6. Build the complete CMake project.
echo
echo "========== Configure CMake =========="
cmake -S . -B build

echo
echo "========== Build complete project =========="
cmake --build build --parallel 2

# 7. Display the header and Git status.
echo
echo "========== Updated header =========="
cat include/system_info.hpp

echo
echo "========== Git status =========="
git status --short

echo
echo "SUCCESS: Uptime and process enumeration implemented."
echo "Integration test: $PROJECT_DIR/uptime_process_check"
echo "Main executable: $PROJECT_DIR/build/system-monitor"

