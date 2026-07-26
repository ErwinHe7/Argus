#include "axio/quant_os.hpp"

#include <atomic>
#include <chrono>
#include <csignal>
#include <iostream>
#include <thread>

namespace {
std::atomic<bool> running{true};
void stop(int) { running = false; }
}

int main() {
  std::signal(SIGINT, stop);
  std::signal(SIGTERM, stop);
  std::cout << "{\"service\":\"axiod\",\"state\":\"RUNNING\","
               "\"mode\":\"PAPER_ONLY\",\"kill_switch\":true,"
               "\"transport\":\"LOCAL_PROCESS\"}" << std::endl;
  while (running.load()) std::this_thread::sleep_for(std::chrono::milliseconds(250));
  std::cout << "{\"service\":\"axiod\",\"state\":\"STOPPED\"}" << std::endl;
  return 0;
}
