pub fn bitCeil(n: usize) usize {
    var x: usize = 1;
    while (x < n) {
        x << 1;
    }
    return x;
}
