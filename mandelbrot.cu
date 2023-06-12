#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

#include <cmath>
#include <ctype>
#include <cstdint>
#include <cuda_runtime.h>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

constexpr int WIDTH = 800;
constexpr int HEIGHT = 600;
constexpr int MAX_ITERATIONS = 1000;
constexpr float ZOOM_FACTOR = 0.9;
constexpr int FPS = 30;

// check if string is a integer (does not check for overflow or negative numbers)
bool is_number(const std::string& s)
{
    std::string::const_iterator it = s.begin();
    while (it != s.end() && std::isdigit(*it)) ++it;
    return !s.empty() && it == s.end();
}

struct Color
{
    uint8_t red;
    uint8_t green;
    uint8_t blue;

    __device__ Color(uint8_t r, uint8_t g, uint8_t b) : red(r), green(g), blue(b) {}
};

// get a "random" color based on the interations after which the iteration producing the mandelbrot set becomes unsable
__device__ Color getColor(int iteration)
{
    int red = (iteration % 8) * 32;
    int green = (iteration % 16) * 16;
    int blue = (iteration % 32) * 8;

    return Color(red, green, blue);
}

// kelnel to quickly generate mandelbrot set interations by pixel
__global__ void generateMandelbrot(uint8_t* image, float zoom, float centerX, float centerY)
{
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x >= WIDTH || y >= HEIGHT)
        return;

    // the actuall mandelbrot set interations, accounting for a shift and a zoom level
    float zx = 0.0;
    float zy = 0.0;
    float cx = centerX + (x - WIDTH / 2) / (0.5 * zoom * WIDTH);
    float cy = centerY + (y - HEIGHT / 2) / (0.5 * zoom * HEIGHT);

    int iteration = 0;
    while (zx * zx + zy * zy < 4.0 && iteration < MAX_ITERATIONS)
    {
        float xtemp = zx * zx - zy * zy + cx;
        zy = 2.0 * zx * zy + cy;
        zx = xtemp;
        iteration++;
    }

    Color color = getColor(iteration);
    image[(y * WIDTH + x) * 3 + 0] = color.red;
    image[(y * WIDTH + x) * 3 + 1] = color.green;
    image[(y * WIDTH + x) * 3 + 2] = color.blue;
}

int main(int argc, char* argv[])
{
    int frames = FPS * (argc > 1 && is_number(argv[1]) ? atoi(argv[1]) : 10);
    
    constexpr dim3 block(16, 16);
    constexpr dim3 grid((WIDTH + block.x - 1) / block.x, (HEIGHT + block.y - 1) / block.y);

    uint8_t* deviceImage;
    cudaMalloc(&deviceImage, WIDTH * HEIGHT * 3 * sizeof(uint8_t));
    uint8_t* hostImage = new uint8_t[WIDTH * HEIGHT * 3];
    char filename[256];

    float centerX = -1.4002;  // X-coordinate of the center of the zoom
    float centerY = 0.0;   // Y-coordinate of the center of the zoom

    for (int frame = 0; frame < frames; frame++)
    {
        float zoom = std::sqrt(frame + 1) * ZOOM_FACTOR;
        generateMandelbrot<<<grid, block>>>(deviceImage, zoom, centerX, centerY);
        cudaDeviceSynchronize();

        cudaMemcpy(hostImage, deviceImage, WIDTH * HEIGHT * 3 * sizeof(uint8_t), cudaMemcpyDeviceToHost);
        snprintf(filename, sizeof(filename), "./frames/frame%d.png", frame);
        
        // Writing the Image to disk
        stbi_write_png(filename, WIDTH, HEIGHT, 3, hostImage, WIDTH * 3);
    }

    delete[] hostImage;
    cudaFree(deviceImage);

    return 0;
}
