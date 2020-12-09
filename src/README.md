# Raytrace in zig

Based on https://raytracing.github.io/books/RayTracingInOneWeekend.html

## TODO

- Russian roulette depth check for end of recursion
  https://www.youtube.com/watch?v=vPwiqXjDgeo&list=PLujxSBD-JXgnGmsn7gEyN28P1DnRZG7qi&index=27

- Haldon or Sobol sampling
  - https://en.wikipedia.org/wiki/Halton_sequence
  - https://en.wikipedia.org/wiki/Sobol_sequence
  - http://www.pbr-book.org/3ed-2018/Sampling_and_Reconstruction/Stratified_Sampling.html
  - small_paint_painterly.cpp
```c++
class Halton {
	double value, inv_base;
public:
	void number(int i, int base) {
		double f = inv_base = 1.0 / base;
		value = 0.0;
		while (i > 0) {
			value += f*(double)(i%base);
			i /= base;
			f *= inv_base;
		}
	}
	void next() {
		double r = 1.0 - value - 0.0000001;
		if (inv_base < r) value += inv_base;
		else {
			double h = inv_base, hh;
			do { hh = h; h *= inv_base; } while (h >= r);
			value += hh + h - 1.0;
		}
	}
	double get() { return value; }
};
```


