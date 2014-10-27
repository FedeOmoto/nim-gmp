import gmp

var
  a,b: mpz_t
  
#converter toPtr(a: var mpz_t): mpz_ptr =
#  cast[mpz_ptr](a.addr)  
  
discard mpz_init_set_str(a.addr,"10",10)
discard mpz_init_set_str(b.addr,"1000000000",10)
mpz_add(a.addr,a.addr,b.addr)
echo mpz_get_str(nil,10,a.addr)

echo sizeof(mp_limb_t)
echo sizeof(mp_limb_signed_t)
echo sizeof(mp_bitcnt_t)
