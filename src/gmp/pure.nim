# it is planned to convert the wrapper into a 'pure' form i.e no header includes
# example of how we could do it:
type
  mp_limb_t* = culong # FIXME: byref doesn't work for culong
  mm_mpz_struct* {.pure, packed, byref.} = object 
    mp_alloc*: cint
    mp_size*: cint
    mp_d*: ptr mp_limb_t
  mpz_t* = mm_mpz_struct

# work out a way to extract arg names  
proc mpz_init*(a2: var mpz_t) {.importc: "__gmpz_init", dynlib: "libgmp.so", cdecl.}
proc mpz_add*(a2: var mpz_t; a3: mpz_t; a4: mpz_t) {.importc: "__gmpz_add", 
    dynlib: "libgmp.so", cdecl.}
proc mpz_get_str*(a2: cstring; base: cint; a4: mpz_t): cstring {.
    importc: "__gmpz_get_str", dynlib: "libgmp.so", cdecl.}
    
proc mpz_set_si*(a2: var mpz_t; a3: clong) {.importc: "__gmpz_set_si", 
    dynlib:"libgmp.so", cdecl.}
    
proc test(a: var mp_limb_t) =
  echo "ok"

var limb = mp_limb_t(0)
test(limb)

var a = mpz_t()
var b = mpz_t()
var c = mpz_t()

mpz_init(a)
mpz_init(b)
mpz_init(c)
mpz_set_si(b,12)
mpz_set_si(c,13)

mpz_add(a,b,c)
echo mpz_get_str(nil,10,a)


