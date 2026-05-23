#include <iostream>
#include "../src/base_add.h"

int main() {
    ap_int<32> result = 0;

    base_add(10, 3, 0, &result);
    if (result != 13) {
        std::cout << "FAIL: mode 0 add, result = " << result << std::endl;
        return 1;
    }

    base_add(10, 3, 1, &result);
    if (result != 7) {
        std::cout << "FAIL: mode 1 sub, result = " << result << std::endl;
        return 1;
    }

    base_add(10, 3, 2, &result);
    if (result != 30) {
        std::cout << "FAIL: mode 2 mul, result = " << result << std::endl;
        return 1;
    }

    base_add(10, 3, 99, &result);
    if (result != 0) {
        std::cout << "FAIL: default mode, result = " << result << std::endl;
        return 1;
    }

    base_add(3, 5, 1, &result);
    if (result != -2) {
        std::cout << "FAIL: signed sub, result = " << result << std::endl;
        return 1;
    }

    std::cout << "PASS" << std::endl;
    return 0;
}

