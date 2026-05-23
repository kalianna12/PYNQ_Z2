#include <iostream>
#include "../src/base_add.h"

int main() {
    int buffer[BUFFER_WORDS];

    for (int i = 0; i < BUFFER_WORDS; i++) {
        buffer[i] = 0;
    }

    int n = 1024;

    base_add(buffer, n);

    int errors = 0;

    for (int i = 0; i < n; i++) {
        int expected_ch0 = i;
        int expected_ch1 = n - 1 - i;

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

