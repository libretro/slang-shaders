#version 450
#define NNEDI3_VERTICAL 0
#define NNEDI3_RGB 1
#define NNEDI3_USE_GATHER 0
#include "nnedi3-predict-common.inc"
#include "nnedi3-nns16-win8x4-kernel.inc"

void main()
{
    FragColor = nnedi3_predict();
}
