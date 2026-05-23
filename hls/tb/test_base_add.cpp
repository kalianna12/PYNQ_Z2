#include <iostream>
#include "../src/base_add.h"

int main() {
    ap_uint<32> result = 0;

    base_add(123, 456, &result);

    if (result != 579) {
        std::cerr << "FAIL: expected 579, got " << result << std::endl;
        return 1;
    }

    std::cout << "PASS: base_add 123 + 456 = " << result << std::endl;
    return 0;
}

