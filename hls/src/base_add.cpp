#include "base_add.h"

void base_add(ap_int<32> a, ap_int<32> b,ap_int<32> mode, ap_int<32> *result) {
#pragma HLS INTERFACE s_axilite port=a bundle=CTRL
#pragma HLS INTERFACE s_axilite port=b bundle=CTRL
#pragma HLS INTERFACE s_axilite port=result bundle=CTRL
#pragma HLS INTERFACE s_axilite port=mode bundle=CTRL
#pragma HLS INTERFACE s_axilite port=return bundle=CTRL
    if(mode==0) *result = a + b;
    else if(mode==1) *result = a - b;
    else if(mode==2) *result = a * b;
    else *result = 0;
}

