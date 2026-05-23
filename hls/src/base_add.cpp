#include "base_add.h"

void base_add(ap_uint<32> a, ap_uint<32> b, ap_uint<32> *result) {
#pragma HLS INTERFACE s_axilite port=a bundle=CTRL
#pragma HLS INTERFACE s_axilite port=b bundle=CTRL
#pragma HLS INTERFACE s_axilite port=result bundle=CTRL
#pragma HLS INTERFACE s_axilite port=return bundle=CTRL

    *result = a + b;
}

