# mandelbrot
Using cuda to generate the mandelbrot set and zoom in

This is a project for a coursera curse

You can run the compile the code with the following command:

```bash 
nvcc mandelbrot.cu -I. -o mandelbrot
```

And then run it and create a video:

```bash
./mandelbrot
ffmpeg -framerate 30 -i frames/frame%d.png -c:v libx264 -pix_fmt yuv420p mandelbrot_video.mp4

```

The project uses the following libraries:
stb_image_write:
  - A single header only library to generate png images

The project uses the following tools:
ffmpeg:
  - To generate the video from the images

A sample video is provided in the repo
you can see it here
[mandelbrot video](mandelbrot_video.mp4)