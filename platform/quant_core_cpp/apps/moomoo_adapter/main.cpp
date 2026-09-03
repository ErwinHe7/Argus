#include <chrono>
#include <cstring>
#include <iostream>
#include <string>

#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
#else
#include <arpa/inet.h>
#include <sys/socket.h>
#include <unistd.h>
#endif

namespace {

bool loopback_only(const std::string& host) {
  return host == "127.0.0.1" || host == "::1" || host == "localhost";
}

bool tcp_check(const std::string& host, unsigned short port) {
  if (!loopback_only(host)) return false;
#ifdef _WIN32
  WSADATA data{};
  if (WSAStartup(MAKEWORD(2, 2), &data) != 0) return false;
#endif
  const int socket_handle = static_cast<int>(::socket(AF_INET, SOCK_STREAM, IPPROTO_TCP));
  if (socket_handle < 0) return false;
  sockaddr_in address{};
  address.sin_family = AF_INET;
  address.sin_port = htons(port);
  address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  const bool connected = ::connect(socket_handle, reinterpret_cast<sockaddr*>(&address),
                                   sizeof(address)) == 0;
#ifdef _WIN32
  closesocket(static_cast<SOCKET>(socket_handle));
  WSACleanup();
#else
  close(socket_handle);
#endif
  return connected;
}

}  // namespace

int main(int argc, char** argv) {
  std::string host = "127.0.0.1";
  unsigned short port = 11111;
  for (int index = 1; index < argc; ++index) {
    const std::string arg = argv[index];
    if (arg == "--host" && index + 1 < argc) host = argv[++index];
    else if (arg == "--port" && index + 1 < argc) port = static_cast<unsigned short>(std::stoi(argv[++index]));
  }
  if (!loopback_only(host)) {
    std::cerr << "OpenD adapter refuses non-loopback host\n";
    return 2;
  }
  const bool connected = tcp_check(host, port);
  std::cout << "{\"provider\":\"MOOMOO_OPEND\",\"quote_only\":true,"
               "\"trade_api_linked\":false,\"host\":\""
            << host << "\",\"port\":" << port << ",\"tcp_connected\":"
            << (connected ? "true" : "false")
            << ",\"consolidated_nbbo\":false,"
               "\"market_coverage\":\"NASDAQ_BASIC_TOTALVIEW_PLUS_ARCABOOK\","
               "\"sdk_version\":\"10.9.6908\","
               "\"protocol_status\":\""
            << (connected ? "OFFICIAL_QUOTE_HANDSHAKE_REQUIRED" : "DISCONNECTED") << "\"}\n";
  return connected ? 0 : 3;
}
