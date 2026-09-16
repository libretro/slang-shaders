#version 450
#define NNEDI3_VERTICAL 1
#define NNEDI3_RGB 1
#include "nnedi3-predict-common.inc"
#include "nnedi3-nns128-win8x4-kernel.inc"

void main()
{
    FragColor = nnedi3_predict();
}
