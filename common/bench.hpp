#pragma once
#include <chrono>
#include <fstream>
#include <string>
#include <filesystem>

struct CpuTimer {
	using clock = std::chrono::high_resolution_clock;
	clock::time_point t0;
	void tic() { t0 = clock::now(); }
	double toc_ms() const {
		auto t1 = clock::now();
		return std::chrono::duration<double, std::milli>(t1 - t0).count();
	}
};

inline void append_csv_row(
		const std::string& path,
		const std::string& header,
		const std::string& row
		){
	namespace fs = std::filesystem;
	bool need_header = !fs::exists(path) || fs::file_size(path) == 0;

	std::ofstream ofs(path, std::ios::app);
	if (!ofs) return;

	if (need_header) ofs << header << '\n';
	ofs << row << '\n';
}
