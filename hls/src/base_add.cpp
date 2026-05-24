#include "base_add.h"

void base_add(
    volatile int *buffer,
    int sample_count,
    int capture_mode,
    hls::stream<sample_word_t> &sample_stream
) {
#pragma HLS INTERFACE m_axi port=buffer offset=slave bundle=GMEM depth=131072
#pragma HLS INTERFACE axis port=sample_stream
#pragma HLS INTERFACE s_axilite port=buffer bundle=CTRL
#pragma HLS INTERFACE s_axilite port=sample_count bundle=CTRL
#pragma HLS INTERFACE s_axilite port=capture_mode bundle=CTRL
#pragma HLS INTERFACE s_axilite port=return bundle=CTRL

    int n = sample_count;

    if (n < 1) {
        n = 1;
    }

    if (n > MAX_SAMPLE_N) {
        n = MAX_SAMPLE_N;
    }

    for (int i = 0; i < n; i++) {
#pragma HLS LOOP_TRIPCOUNT min=1 max=65536
#pragma HLS PIPELINE II=1

        int phase = i & 255;
        int tri;

        if (phase < 128) {
            tri = phase * 16;
        } else {
            tri = (255 - phase) * 16;
        }

        int ch0;
        int ch1;

        if (capture_mode == 0) {
            ch0 = tri;
            ch1 = tri / 2;
        } else {
            sample_word_t word = sample_stream.read();
            ch0 = (int)(word.range(11, 0));
            ch1 = (int)(word.range(27, 16));
        }

        buffer[i] = ch0;
        buffer[MAX_SAMPLE_N + i] = ch1;
    }
}
