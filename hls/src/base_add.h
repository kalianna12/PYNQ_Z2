#ifndef BASE_ADD_H
#define BASE_ADD_H

#include <ap_int.h>
#include <hls_stream.h>

#define MAX_SAMPLE_N 65536
#define BUFFER_WORDS 131072

typedef ap_uint<32> sample_word_t;

void base_add(
    volatile int *buffer,
    int sample_count,
    int capture_mode,
    hls::stream<sample_word_t> &sample_stream
);

#endif

