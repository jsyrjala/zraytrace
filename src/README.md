
`inline pub fn` is not ok, `pub inline fn` is ok.
Should have more descriptive error
```
inline pub fn length_sqrt(self: Vec3) f32 {
    return self.x * self.x + self.y * self.y + self.z * self.z;
}
=>
./src/main.zig:34:12: error: invalid token: 'pub'
    inline pub fn length_sqrt(self: Vec3) f32 {
           ^
```
