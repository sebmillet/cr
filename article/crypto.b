	/* Calculate the invert of a modulo n */
define invmod(a, n) {
	auto aa, bb, r, t, anc_t, nou_t, negflag
	aa = n
	negflag = 0
	if (a < 0) {
		negflag = 1
		a %= n
		if (a < 0) a += n
	}
	bb = a
	r = 1
	t = 1
	anc_t = 0
	while (1) {
		q = aa / bb
		anc_r = r
		r = aa - bb * q

		nou_t = anc_t - q * t
		if (nou_t >= 0) nou_t %= n
		if (nou_t < 0) nou_t = n - (-nou_t % n)
		anc_t = t
		t = nou_t

		aa = bb
		bb = r
		if (r <= 1) break;
	}

	if (r != 1) {
			/*
			   No invert can be returned => error
			   Alternate solution: return -1

			   I find triggering an error best: the calculation stops
			   immediately instead of continuing with meaningless values
			*/
		return 1 % 0
	} else {
		if (negflag) t -= n
		return t
	}
}

/*
	The well-known powmod function, sometimes referred to in bc scripts
	as "mpower".
*/
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

/*
	The EC functions below use the following conventions.

	- A point is given by an array in which array[0] is the x coordinate and
	  array[1] is the y coordinate.

	- The point at infinity has its x coordinate (array[0]) equal to -1
*/

/*
	ECC addition of p and q, p being different from q
*/
define void ec_add(*r[], p[], q[], m) {
	auto s
	if (p[0] == -1) { r[0] = q[0]; r[1] = q[1]; return }
	if (q[0] == -1) { r[0] = p[0]; r[1] = p[1]; return }
	s = ((p[1] - q[1]) * invmod(p[0] - q[0], m)) % m
	r[0] = (s^2 - p[0] - q[0]) % m
	r[1] = (s * (p[0] - r[0]) - p[1]) % m
}

/*
   ECC point doubling
*/
define void ec_dbl(*r[], p[], a, m) {
	auto s
	s = ((3 * p[0]^2 + a) * invmod(2 * p[1], m)) % m
	r[0] = (s^2 - 2 * p[0]) % m
	r[1] = (s * (p[0] - r[0]) - p[1]) % m
}

/*
   ECC scalar point multiplication
*/
define void ec_mul(*r[], p[], k, a, m) {
	auto tmp[]
	r[0] = -1
	r[1] = 0
	while (k > 0) {
		if ((k % 2) == 1) {
			ec_add(r[], r[], p[], m)
		}
			/*
			 * ec_dbl(p[], p[], a, m) does not work with bc,
			 * need to use a temporary array.
			 */
		ec_dbl(tmp[], p[], a, m)
		p[0]=tmp[0]
		p[1]=tmp[1]
		k /= 2
	}
	if (r[0] < 0) r[0] += m
	if (r[1] < 0) r[1] += m
}

