#ifndef BASE_ADD_H
#define BASE_ADD_H

#include <ap_int.h>

#define MAX_SAMPLE_N 1024
#define BUFFER_WORDS (MAX_SAMPLE_N * 2)

void base_add(volatile int *buffer, int sample_count);

#endif

