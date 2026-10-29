#include "system_info.hpp"

#include <gtest/gtest.h>

#include <chrono>
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
