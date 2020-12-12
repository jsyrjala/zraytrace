# zraytrace

Ray tracing implemented in [Zig](https://ziglang.org/).

## Inspiration

Code follows mostly [Ray Tracing in One Weekend](https://raytracing.github.io/) and [Physically Based Rendering](http://www.pbr-book.org/). 

## Features

Single threaded, uses only on CPU.

Materials:
- diffuse (matte)
- metal (fully reflective)
- dielectric (glass like objects)

Shapes
- sphere
- triangle

Textures:
- constant color
- image textures

Algorithms
- Bounded volume hierarchy

File formats:
- PNG images, read and write
- OBJ 3d models, read

# Examples

## Spheres

This doesn't use bounded volume hierarchy because its overhead is too big for scene with 7 spheres.

![7 spheres with various materials and textures](https://github.com/jsyrjala/zraytrace/raw/master/showcase/7-spheres.png)

From the left:
- reflective texture mapped sphere (earth)
- hollow dielectric sphere (glass)
- diffuse texture mapped sphere (Nitor logo)
- filled dielectric sphere (glass)
- reflective sphere with silver color (mirror ball)
- diffuse green sphere (ground level)

Some statistics
- Surfaces:                 7
- Pixels:                   1000x1000
- Samples per pixel:        1000
- Max recursion depth:      30
- Total reflections:     1144753226
- Total background hits: 999892115
- Total pixels:          1000000
- Total samples:         1000000000
- Total rays:            2144645362
- Total reflections:     1144753226
- Pixels per second:     1619.68 pixels/s
- Total runtime:         617.41 seconds

