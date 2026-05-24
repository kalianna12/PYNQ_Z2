#include <iostream>
#include "../src/base_add.h"

int calc_tri(int i) {
    int phase = i & 255;
    int tri;

    if (phase < 128) {
        tri = phase * 16;
    } else {
        tri = (255 - phase) * 16;
    }

    return tri;
}

int main() {
    int buffer[BUFFER_WORDS];

    for (int i = 0; i < BUFFER_WORDS; i++) {
        buffer[i] = 0;
    }

    int n = 1024;

    base_add(buffer, n);

    int errors = 0;

    for (int i = 0; i < n; i++) {
        int expected_ch0 = calc_tri(i);
        int expected_ch1 = expected_ch0 / 2;

        if (buffer[i] != expected_ch0) {
            std::cout << "FAIL CH0: i=" << i
                      << ", got=" << buffer[i]
                      << ", expected=" << expected_ch0
                      << std::endl;
            errors++;
            break;
        }

        if (buffer[MAX_SAMPLE_N + i] != expected_ch1) {
            std::cout << "FAIL CH1: i=" << i
                      << ", got=" << buffer[MAX_SAMPLE_N + i]
                      << ", expected=" << expected_ch1
                      << std::endl;
            errors++;
            break;
        }
    }

    if (errors == 0) {
        std::cout << "FINAL: PASS" << std::endl;
        return 0;
    }

    std::cout << "FINAL: FAIL, errors=" << errors << std::endl;
    return 1;
}