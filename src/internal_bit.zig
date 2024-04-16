pub fn bitCeil(n: usize) usize {
    var x: usize = 1;
    while (x < n) {
        x *= 2;
    }
    return x;
}
