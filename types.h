#ifndef C2CB3CD7_D2FD_4F9E_B362_7E7B98FB9DD8
#define C2CB3CD7_D2FD_4F9E_B362_7E7B98FB9DD8
#include <cstdint>

typedef unsigned char pixelv __attribute__((vector_size(4)));
typedef char spixelv __attribute((vector_size(4)));
typedef int calcv __attribute((vector_size(4 * sizeof(int))));

enum GPUOptions {
    COLOR_REPLACE = 0,
    BDITHER = 1 << 0,
    LUMA_INVERT = 1 << 1
};

extern "C" int32_t doGPUSlut(void *inst_, uint8_t *pixels_ptr, uint32_t px_w, uint32_t px_h, uint32_t *lut_ptr, uint32_t lut_imsize);
extern "C" uint8_t *doGPUGlut(void* inst, uint32_t *pal, uint32_t palSize, uint32_t level);
extern "C" int32_t doGPUWork(void* inst, uint32_t *pxs, uint32_t pxw, uint32_t pxh, uint8_t options, uint32_t *pal, uint32_t pals);
extern "C" void* doGPUInit();
extern "C" void doGPUDeinit(void* inst);

extern "C" int32_t doNNS(uint32_t *pxs, uint32_t pxw, uint32_t pxh, uint8_t, uint32_t *pal, uint32_t pals);

void ditherPass(long start_h, long height, long width, pixelv*);
pixelv lumaInvert(pixelv &c);
pixelv findNearest(pixelv &find);
uint32_t *loadPalette(uint32_t *n, const char *filePath);

#endif /* C2CB3CD7_D2FD_4F9E_B362_7E7B98FB9DD8 */
