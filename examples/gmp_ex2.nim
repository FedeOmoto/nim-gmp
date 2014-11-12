## example showing simple addition. This one reallys shows the power of
## of big ints: we calculate a number equal to 25 - normally you would run out
## of fingers when calculating this!

import gmp
import gmp/utils

var res = init_mpz() # initialized to zero
let x: mpz = 10 # convert int to mpz_t
let y = init_mpz("15",10) # construct from string (base: 10)

mpz_add(res,x,y)

# a few comparisons for good measure
assert x < y 
assert x != y

echo res # prints 25
