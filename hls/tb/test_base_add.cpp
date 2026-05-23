#include <iostream>
#include "../src/base_add.h"

int main() {
    int result = 0;

    base_add(1, 2, 3, 4, 5, 6, 7, 8, &result);

    if (result != 36) {
        std::cout << "FAIL: result = " << result
                  << ", expected = 36" << std::endl;
        return 1;
    }

    std::cout << "PASS" << std::endl;
    return 0;
}

