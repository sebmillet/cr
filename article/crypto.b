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

	- The point at infinity has non null element of index 2 (array[2]!=0),
	  for any other point, array[2] is zero.

	- If array[2] is zero, array[0] is the x coordinate and
	  array[1] is the y coordinate.

*/

/*
	ECC addition of p and q, p[0] being different from q[0]
*/
define void ec_add_core(*r[], p[], q[], m) {
	auto s
	s = ((p[1] - q[1]) * invmod(p[0] - q[0], m)) % m
	r[0] = (s^2 - p[0] - q[0]) % m
	r[1] = (s * (p[0] - r[0]) - p[1]) % m
	r[2] = 0
}

/*
   ECC point doubling
*/
define void ec_dbl_core(*r[], p[], a, m) {
	auto s
	s = ((3 * p[0]^2 + a) * invmod(2 * p[1], m)) % m
	r[0] = (s^2 - 2 * p[0]) % m
	r[1] = (s * (p[0] - r[0]) - p[1]) % m
	r[2] = 0
}

/*
	ECC addition of p and q for any value of p and q
*/
define void ec_add(*r[], p[], q[], a, m) {
	if (p[2]) { r[0] = q[0]; r[1] = q[1]; r[2] = q[2]; return }
	if (q[2]) { r[0] = p[0]; r[1] = p[1]; r[2] = p[2]; return }
	if (p[0] == q[0]) {
		if (p[1] != q[1]) {
			r[2] = 1  /* We don't verify whether p[1]==-q[1] as it should... */
		} else {
			if (p[2]) {
				r[2] = 1
				return
			}
			ec_dbl_core(r[], p[], a, m)
		}
	} else {
		ec_add_core(r[], p[], q[], m)
	}
}

/*
   ECC scalar point multiplication
*/
define void ec_mul(*r[], p[], k, a, m) {
	auto tmp[]
	r[2] = 1
	if (p[2]) return
	while (k > 0) {
		if ((k % 2) == 1) {
			ec_add(r[], r[], p[], a, m)
		}
			/*
			 * ec_dbl(p[], p[], a, m) does not work with bc,
			 * need to use a temporary array.
			 */
		ec_add(tmp[], p[], p[], a, m)
		p[0]=tmp[0]
		p[1]=tmp[1]
		p[2]=tmp[2]
		k /= 2
	}
	if (!r[2]) {
		if (r[0] < 0) r[0] += m
		if (r[1] < 0) r[1] += m
	}
}

