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
