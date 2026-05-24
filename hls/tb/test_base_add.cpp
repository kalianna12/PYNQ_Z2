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

int check_buffer(int *buffer, int n, int (*expected_ch0)(int), int (*expected_ch1)(int), const char *name) {
    for (int i = 0; i < n; i++) {
        int ch0 = expected_ch0(i);
        int ch1 = expected_ch1(i);

        if (buffer[i] != ch0) {
            std::cout << "FAIL " << name << " CH0: i=" << i
                      << ", got=" << buffer[i]
                      << ", expected=" << ch0
                      << std::endl;
            return 1;
        }

        if (buffer[MAX_SAMPLE_N + i] != ch1) {
            std::cout << "FAIL " << name << " CH1: i=" << i
                      << ", got=" << buffer[MAX_SAMPLE_N + i]
                      << ", expected=" << ch1
                      << std::endl;
            return 1;
        }
    }

    return 0;
}

int fake_ch0(int i) {
    return calc_tri(i);
}

int fake_ch1(int i) {
    return calc_tri(i) / 2;
}

int stream_ch0(int i) {
    return i & 0xFFF;
}

int stream_ch1(int i) {
    return (4095 - i) & 0xFFF;
}

void fill_stream(hls::stream<sample_word_t> &sample_stream, int n) {
    for (int i = 0; i < n; i++) {
        sample_word_t word = 0;
        word.range(11, 0) = stream_ch0(i);
        word.range(27, 16) = stream_ch1(i);
        sample_stream.write(word);
    }
}

void clear_buffer(int *buffer) {
    for (int i = 0; i < BUFFER_WORDS; i++) {
        buffer[i] = -12345;
    }
}

int main() {
    int buffer[BUFFER_WORDS];
    int errors = 0;
    hls::stream<sample_word_t> sample_stream;

    clear_buffer(buffer);
    int n = 1024;
    base_add(buffer, n, 0, sample_stream);
    errors += check_buffer(buffer, n, fake_ch0, fake_ch1, "FAKE");

    clear_buffer(buffer);
    int stream_n = 64;
    fill_stream(sample_stream, stream_n);
    base_add(buffer, stream_n, 1, sample_stream);
    errors += check_buffer(buffer, stream_n, stream_ch0, stream_ch1, "STREAM_MODE1");

    clear_buffer(buffer);
    fill_stream(sample_stream, stream_n);
    base_add(buffer, stream_n, 2, sample_stream);
    errors += check_buffer(buffer, stream_n, stream_ch0, stream_ch1, "STREAM_MODE2");

    clear_buffer(buffer);
    fill_stream(sample_stream, 1);
    base_add(buffer, 0, 2, sample_stream);
    errors += check_buffer(buffer, 1, stream_ch0, stream_ch1, "ZERO_COUNT_CLAMP");

    clear_buffer(buffer);
    fill_stream(sample_stream, 1);
    base_add(buffer, -7, 1, sample_stream);
    errors += check_buffer(buffer, 1, stream_ch0, stream_ch1, "NEG_COUNT_CLAMP");

    clear_buffer(buffer);
    base_add(buffer, MAX_SAMPLE_N + 128, 0, sample_stream);
    errors += check_buffer(buffer, MAX_SAMPLE_N, fake_ch0, fake_ch1, "MAX_COUNT_CLAMP");
    if (buffer[MAX_SAMPLE_N - 1] == -12345 || buffer[BUFFER_WORDS - 1] == -12345) {
        std::cout << "FAIL MAX_COUNT_CLAMP did not fill clamped end samples" << std::endl;
        errors++;
    }

    if (errors == 0) {
        std::cout << "FINAL: PASS" << std::endl;
        return 0;
    }

    std::cout << "FINAL: FAIL, errors=" << errors << std::endl;
    return 1;
}
