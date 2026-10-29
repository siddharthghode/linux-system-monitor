
#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="${1:-$HOME/sppu/git/linux-system-monitor}"

echo "======================================="
echo " Linux System Monitor - Google Test Setup"
echo "======================================="

if [[ ! -f "$PROJECT_DIR/CMakeLists.txt" ||
      ! -f "$PROJECT_DIR/include/system_info.hpp" ]]; then
    echo "ERROR: Project not found: $PROJECT_DIR"
    exit 1
fi

for tool in cmake g++ git; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "ERROR: Missing tool: $tool"
        exit 1
    }
done

cd "$PROJECT_DIR"

# Install Google Test
echo
echo "========== Installing Google Test =========="
sudo apt update
sudo apt install -y libgtest-dev

echo
echo "========== Locating GTestConfig.cmake =========="
find /usr -name GTestConfig.cmake 2>/dev/null | head || true

# Append testing configuration only once
if ! grep -q 'gtest_discover_tests(system-monitor-tests)' CMakeLists.txt; then
    cat >> CMakeLists.txt <<'EOF'

# Google Test configuration
enable_testing()

find_package(GTest REQUIRED)

add_executable(system-monitor-tests
    tests/test_system_info.cpp
    src/cpu.cpp
)

target_link_libraries(system-monitor-tests
    PRIVATE system_info GTest::gtest_main
)

target_compile_options(system-monitor-tests
    PRIVATE -Wall -Wextra -Wpedantic
)

include(GoogleTest)
gtest_discover_tests(system-monitor-tests)
EOF
    echo "Added Google Test configuration."
else
    echo "Google Test configuration already exists."
fi

# Create the test suite
cat > tests/test_system_info.cpp <<'EOF'
#include "system_info.hpp"

#include <gtest/gtest.h>

#include <cmath>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace fs = std::filesystem;

namespace {

class ProcParserTest : public ::testing::Test {
protected:
    fs::path fixture;

    void SetUp() override
    {
        fixture = fs::temp_directory_path()
                / ("system-monitor-tests-"
                   + std::to_string(
                       std::chrono::steady_clock::now()
                           .time_since_epoch().count()));

        fs::create_directories(fixture);
    }

    void TearDown() override
    {
        std::error_code ec;
        fs::remove_all(fixture, ec);
    }

    void write_file(const fs::path& name, const std::string& content)
    {
        std::ofstream file(fixture / name);
        ASSERT_TRUE(file.good());
        file << content;
        ASSERT_TRUE(file.good());
    }
};

TEST_F(ProcParserTest, ParsesMemoryInformation)
{
    write_file("meminfo",
        "MemTotal:       1000 kB\n"
        "MemFree:         200 kB\n"
        "MemAvailable:    600 kB\n");

    const auto info = read_memory_info(
        (fixture / "meminfo").string());

    EXPECT_EQ(info.total_kb, 1000);
    EXPECT_EQ(info.available_kb, 600);
    EXPECT_EQ(info.used_kb, 400);
}

TEST_F(ProcParserTest, MissingMemoryFileThrows)
{
    EXPECT_THROW(
        read_memory_info((fixture / "missing").string()),
        std::runtime_error);
}

TEST_F(ProcParserTest, CalculatesCpuUsage)
{
    const CpuTimes previous{100, 200};
    const CpuTimes current{150, 300};

    EXPECT_NEAR(
        calculate_cpu_usage(previous, current),
        50.0,
        0.001);
}

TEST_F(ProcParserTest, CpuUsageIsZeroWithoutProgress)
{
    const CpuTimes sample{100, 200};

    EXPECT_DOUBLE_EQ(
        calculate_cpu_usage(sample, sample),
        0.0);
}

TEST_F(ProcParserTest, ParsesAggregateCpuTimes)
{
    write_file("stat",
        "cpu 100 20 30 400 50 5 10 2 0 0\n"
        "cpu0 50 10 15 200 25 2 5 1 0 0\n");

    const auto cpu = read_cpu_times(
        (fixture / "stat").string());

    EXPECT_EQ(cpu.idle, 450);
    EXPECT_EQ(cpu.total, 617);
}

TEST_F(ProcParserTest, RejectsInvalidCpuStatistics)
{
    write_file("stat", "not-cpu data\n");

    EXPECT_THROW(
        read_cpu_times((fixture / "stat").string()),
        std::runtime_error);
}

TEST_F(ProcParserTest, ParsesUptime)
{
    write_file("uptime", "12345.67 9876.54\n");

    EXPECT_DOUBLE_EQ(
        read_uptime_seconds((fixture / "uptime").string()),
        12345.67);
}

TEST_F(ProcParserTest, RejectsNegativeUptime)
{
    write_file("uptime", "-1.0 0.0\n");

    EXPECT_THROW(
        read_uptime_seconds((fixture / "uptime").string()),
        std::runtime_error);
}

TEST_F(ProcParserTest, ParsesProcessNameWithSpaces)
{
    const fs::path proc = fixture / "proc";
    fs::create_directories(proc / "123");

    {
        std::ofstream stat(proc / "123" / "stat");
        stat << "123 (my test process) S 1 2 3\n";
    }

    const auto processes = read_processes(proc.string());

    ASSERT_EQ(processes.size(), 1);
    EXPECT_EQ(processes[0].pid, 123);
    EXPECT_EQ(processes[0].name, "my test process");
}

TEST_F(ProcParserTest, IgnoresNonNumericDirectories)
{
    const fs::path proc = fixture / "proc";
    fs::create_directories(proc / "self");
    fs::create_directories(proc / "not-a-pid");

    const auto processes = read_processes(proc.string());

    EXPECT_TRUE(processes.empty());
}

TEST_F(ProcParserTest, MissingProcessDirectoryThrows)
{
    EXPECT_THROW(
        read_processes((fixture / "missing").string()),
        std::runtime_error);
}

} // namespace
EOF

# Ensure chrono is included for the fixture name.
python3 - <<'PY'
from pathlib import Path

p = Path("tests/test_system_info.cpp")
text = p.read_text()

if "#include <chrono>" not in text:
    text = text.replace(
        "#include <cmath>",
        "#include <chrono>\n#include <cmath>",
        1
    )

p.write_text(text)
PY

echo
echo "========== Configure CMake =========="
cmake -S . -B build

echo
echo "========== Build all targets =========="
cmake --build build --parallel 2

echo
echo "========== Run Google Tests =========="
ctest --test-dir build --output-on-failure

echo
echo "========== Git status =========="
git status --short

echo
echo "Google Test setup and test execution completed."

