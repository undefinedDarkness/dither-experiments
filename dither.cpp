#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <functional>
#include <iostream>
#include <filesystem>
#include <thread>

#ifdef __WIN32__
#include <windows.h>
#endif

#include "types.h"

#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "libs/argh.h"
#include "libs/stb_image.h"
#include "libs/stb_image_write.h"

void genericPass(std::function<pixelv(pixelv &)> fn, pixelv *pixels, long width,
                 long height) {
  size_t size = width * height;
#ifdef NDEBUG
  // Divide code into chunks
  //  if chunk is too small then do it linearly
  //  otherwise fire up 4 threads to do the work
  size_t chunk = size / 4;

  if (chunk < 1000) {
    for (int i = 0; i < size; i++)
      pixels[i] = fn(pixels[i]);
  } else {
    size_t rem = size & 3;
    std::array<std::thread, NTHREAD> threads;
    size_t start = 0;
    for (int i = 0; i < NTHREAD; i++) {
      threads[i] = std::thread([=]() {
        for (int j = start; j < start + chunk; j++) {
          pixels[j] = fn(pixels[j]);
        }
      });
      start += chunk;
    }
    if (rem) {
      threads[4] = std::thread([=]() {
        for (int j = start; j < start + rem; j++) {
          pixels[j] = fn(pixels[j]);
        }
      });
    }
    for (int i = 0; i < 4 + (!!rem); i++) {
      threads[i].join();
    }
  }
#else
  for (int i = 0; i < size; i++) {
    pixels[i] = fn(pixels[i]);
  }
#endif
}

//extern "C" void testImpl();
extern "C" int32_t doGPUWork(uint32_t *, uint32_t, uint32_t, uint32_t);
extern "C" void* doGPUInit();

int main(int argc, char **argv) {
  //testImpl();
  #ifdef __WIN32__
  // Hack because windows sucks and won't interpret UTF8 output in the console correctly, same deal for the VSC Console
  SetConsoleOutputCP(CP_UTF8);
  #endif

  argh::parser cmdl(argv);

  if (cmdl[1].empty()) {
    std::cerr << "Nothing to do" << std::endl;
    return 0;
  }

  if (!std::filesystem::exists(cmdl[1])) {
    std::cerr << "File " << cmdl[1] << " doesn't exist.\n";
    return 1;
  }

  unsigned char *pixelData;
  int width, height, channels;
  pixelData = stbi_load(cmdl[1].c_str(), &width, &height, &channels, 4);
  pixelv *pixels = (pixelv *)pixelData;

  // -- MAIN WORK: File is loaded --
  void* gpuInst = doGPUInit();
  if (gpuInst == nullptr) {
    std::cerr << "GPU Compute unavailable returning to CPU operation\n";
  } else {
    std::cerr << "GPU Compute initialized sucessfully\n";
  }

  stbi_write_png("output.png", width, height, 4, pixelData, width * 4); // TODO: FIX SLOW WRITING!!!
  free(pixelData);
  return 0;
}