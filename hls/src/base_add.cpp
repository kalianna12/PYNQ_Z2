#include "base_add.h"

void base_add(
    int x0, int x1, int x2, int x3,
    int x4, int x5, int x6, int x7,
    int *result
) {
#pragma HLS INTERFACE s_axilite port=x0 bundle=CTRL
#pragma HLS INTERFACE s_axilite port=x1 bundle=CTRL
#pragma HLS INTERFACE s_axilite port=x2 bundle=CTRL
#pragma HLS INTERFACE s_axilite port=x3 bundle=CTRL
#pragma HLS INTERFACE s_axilite port=x4 bundle=CTRL
#pragma HLS INTERFACE s_axilite port=x5 bundle=CTRL
#pragma HLS INTERFACE s_axilite port=x6 bundle=CTRL
#pragma HLS INTERFACE s_axilite port=x7 bundle=CTRL
#pragma HLS INTERFACE s_axilite port=result bundle=CTRL
#pragma HLS INTERFACE s_axilite port=return bundle=CTRL

    int arr[8];
    #pragma HLS ARRAY_PARTITION variable=arr block factor=2

    arr[0] = x0;
    arr[1] = x1;
    arr[2] = x2;
    arr[3] = x3;
    arr[4] = x4;
    arr[5] = x5;
    arr[6] = x6;
    arr[7] = x7;

    int sum = 0;

    for (int i = 0; i < 8; i++) {
        #pragma HLS UNROLL factor=2
        sum += arr[i];
    }

    *result = sum;
}

