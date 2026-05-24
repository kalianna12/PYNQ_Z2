#include "base_add.h"

void base_add(volatile int *buffer, int sample_count) {
#pragma HLS INTERFACE m_axi port=buffer offset=slave bundle=GMEM depth=2048
#pragma HLS INTERFACE s_axilite port=buffer bundle=CTRL
#pragma HLS INTERFACE s_axilite port=sample_count bundle=CTRL
#pragma HLS INTERFACE s_axilite port=return bundle=CTRL

    int n = sample_count;

    if (n < 0) {
        n = 0;
    }

    if (n > MAX_SAMPLE_N) {
        n = MAX_SAMPLE_N;
    }

    for (int i = 0; i < n; i++) {
#pragma HLS LOOP_TRIPCOUNT min=1 max=1024
#pragma HLS PIPELINE II=1

        int phase = i & 255;
        int tri;

        if (phase < 128) {
            tri = phase * 16;
        } else {
            tri = (255 - phase) * 16;
        }

        int ch0 = tri;
        int ch1 = tri / 2;

        buffer[i] = ch0;
        buffer[MAX_SAMPLE_N + i] = ch1;
    }
}