define powmod(a, b, c) {
	auto p, r
	p = a
	r = 1
	while (b > 0) {
		if (b % 2) r = (r * p) % c
		p = (p * p) % c
		b /= 2
	}
	return r
}
