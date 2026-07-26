cmake_minimum_required(VERSION 3.24)
project(axio_quant_os VERSION 0.2.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

option(AXIO_WARNINGS_AS_ERRORS "Treat compiler warnings as errors" ON)

find_package(SQLite3 REQUIRED)
find_package(OpenSSL REQUIRED)

add_library(axio_quant_core
  src/quant_os.cpp
)
target_include_directories(axio_quant_core PUBLIC include)
target_link_libraries(axio_quant_core PUBLIC SQLite3::SQLite3 OpenSSL::Crypto)

if(MSVC)
  target_compile_options(axio_quant_core PRIVATE /W4 /permissive-)
  if(AXIO_WARNINGS_AS_ERRORS)
    target_compile_options(axio_quant_core PRIVATE /WX)
  endif()
else()
  target_compile_options(axio_quant_core PRIVATE -Wall -Wextra -Wpedantic -Wconversion -Wshadow)
  if(AXIO_WARNINGS_AS_ERRORS)
    target_compile_options(axio_quant_core PRIVATE -Werror)
  endif()
endif()

add_executable(quantctl apps/quantctl/main.cpp)
target_link_libraries(quantctl PRIVATE axio_quant_core)

add_executable(axiod apps/axiod/main.cpp)
target_link_libraries(axiod PRIVATE axio_quant_core)

add_executable(moomoo_opend_adapter apps/moomoo_adapter/main.cpp)
if(WIN32)
  target_link_libraries(moomoo_opend_adapter PRIVATE ws2_32)
endif()
if(MSVC)
  target_compile_options(moomoo_opend_adapter PRIVATE /W4 /permissive-)
else()
  target_compile_options(moomoo_opend_adapter PRIVATE -Wall -Wextra -Wpedantic -Wconversion -Wshadow)
endif()

enable_testing()
add_executable(axio_quant_tests tests/test_main.cpp)
target_link_libraries(axio_quant_tests PRIVATE axio_quant_core)
add_test(NAME axio_quant_tests COMMAND axio_quant_tests)

install(TARGETS quantctl axiod RUNTIME DESTINATION bin)
