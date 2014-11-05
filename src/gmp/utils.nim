import gmp
import math

################################################################################
# multi-precision ints
################################################################################


proc finalise(a: ref mpz_t) =
  mpz_clear(a[].addr)
 
proc new_mpz_t*(): ref mpz_t =
  new(result,finalise)
  mpz_init(result[].addr)
  
proc init_mpz_t*(): mpz_t =
  mpz_init(result.addr)

converter toPtr*(a: var mpz_t): ptr mpz_t =
  a.addr
  
proc init_mpz_t*(enc: string, base: cint = 10): mpz_t =
  if mpz_init_set_str(result.addr,enc, base) != 0:
    raise newException(ValueError,enc & " represents an invalid value") 
    
converter convert*(a: clong): mpz_t =
  mpz_init_set_si(result.addr,a)

converter convert*(a: mpf_t): mpz_t =
  var temp = a
  result = init_mpz_t()
  mpz_set_f(result.addr, temp.addr)

proc toMpz(a: var mpf_t): mpz_t =
  result = init_mpz_t()
  mpz_set_f(result.addr, a.addr)

proc toMpz(a: clong): mpz_t =
  mpz_init_set_si(result.addr,a)

proc init_mpz_t*(val: clong): mpz_t =
  mpz_init_set_si(result.addr,val)
  
proc new_mpz_t*(val: clong): ref mpz_t =
  new(result,finalise)
  mpz_init_set_si(result[].addr,val)
  
template mpz_p*(a: clong{lit}): mpz_ptr =
  # weird interaction with destructor, so use new for now
  # should stay alive whilst in scope, hence inject
  var temp {.genSym, inject.} = new_mpz_t(a)
  temp[].addr    
  
proc new_mpz_t*(enc: string, base: cint = 10): ref mpz_t =
  new(result,finalise)
  if mpz_init_set_str(result[].addr,enc, base) != 0: 
    raise newException(ValueError,enc & " represents an invalid value")

proc alloc_mpz_t*(shared: bool = true): ptr mpz_t =
  if shared:
    result = cast[ptr mpz_t](allocShared(sizeof(mpz_t)))
  else:
    result = cast[ptr mpz_t](alloc(sizeof(mpz_t)))
  mpz_init(result)
  
proc dealloc_mpz_t*(a: ptr mpz_t, shared: bool = true) =
  mpz_clear(a)
  if shared:
    deallocShared(a)
  else:
    dealloc(a)

proc `==`*(a,b: var mpz_t): bool =
  return mpz_cmp(a.addr,b.addr) == 0
  
proc `<`*(a,b: var mpz_t): bool =
  return mpz_cmp(a.addr,b.addr) < 0

proc `<=`*(a,b: var mpz_t): bool =
  let t = mpz_cmp(a.addr,b.addr)
  t < 0 or t == 0

proc cmp*(a,b: var mpz_t): int =
  return mpz_cmp(a.addr,b.addr)  

proc `$`*(a: var mpz_t, base: cint = 10): string =
  result = newString(mpz_sizeinbase(a.addr, base) + 1)
  return $mpz_get_str(result,base,a.addr)
  
proc `$`*(a: ptr mpz_t, base: cint = 10): string =
  result = newString(mpz_sizeinbase(a, base) + 1)
  return $mpz_get_str(result,base,a)
  
proc copy*(a: var mpz_t): mpz_t =
  ## you must use this function in instead of assignment
  mpz_set(result.addr,a.addr)
  return result
  
# careful when copying values!!!
proc destroy*(a: var mpz_t) {.destructor.} =
  mpz_clear(a.addr)


################################################################################
# multi-precision floats
################################################################################

proc finalise(a: ref mpf_t) =
  mpf_clear(a[].addr)

proc init_mpf_t*(): mpf_t =
  mpf_init(result.addr)
  
proc init_mpf_t*(enc: string, base: cint = 10): mpf_t =
  ## Set the value of rop from the string in str. The string is of the form ‘M@N’
  ## or, if the base is 10 or less, alternatively ‘MeN’. ‘M’ is the mantissa and 
  ## ‘N’ is the exponent. The # mantissa is always in the specified base. The 
  ## exponent is either in the specified base or, if base is negative, in decimal. 
  ## The decimal point expected is taken from the current  locale, on systems 
  ## providing localeconv.
  ##
  ## The argument base may be in the ranges 2 to 62, or −62 to −2. Negative values 
  ## are used to specify that the exponent is in decimal.
  ##
  ## For bases up to 36, case is ignored; upper-case and lower-case letters have the 
  ## same value; for bases 37 to 62, upper-case letter represent the usual 10..35 
  ## while lower-case  letter represent 36..61.
  ##
  ## Unlike the corresponding mpz function, the base will not be determined from the
  ## leading characters of the string if base is 0. This is so that numbers like 
  ## ‘0.23’ are not  interpreted as octal.
  ##
  ## White space is allowed in the string, and is simply ignored. [This is not really 
  ## true; white-space is ignored in the beginning of the string and within the 
  ## mantissa, but not in  other places, such as after a minus sign or in the exponent. 
  if mpf_init_set_str(result.addr,enc,base) != 0:
    # have to free memory even on failure
    mpf_clear(result.addr)
    raise newException(ValueError,enc & " represents an invalid value")
    
proc init_mpf_t*(val: float): mpf_t =
  mpf_init_set_d(result.addr,val)
  
proc new_mpf_t*(val: float): ref mpf_t =
  new(result,finalise)
  mpf_init_set_d(result[].addr,val)
  
proc init_mpf_t*(val: clong): mpf_t =
  mpf_init_set_si(result.addr,val)
  
proc toMpf*(a: float): mpf_t =
  result = init_mpf_t(a)
  
template mpf_p*(a: float{lit}): mpf_ptr =
  # inject so it is finalised when goes out of scope
  var temp {.genSym, inject.} = new_mpf_t(a)
  temp[].addr    
  
proc toMpf*(a: var mpz_t): mpf_t =
  result = init_mpf_t()
  mpf_set_z(result.addr,a.addr)
  
converter toPtr*(a: var mpf_t): ptr mpf_t =
  a.addr
  
converter convert*(a: float): mpf_t =
  a.toMpf

proc copy*(a: var mpf_t): mpf_t =
  ## you must use this function instead of assignment
  mpf_set(result.addr,a.addr)
  return result

template toFloatHelper(result: expr, tooSmall: stmt, tooLarge: stmt) =
  # WARNING: depends on system specific behaviour: on what systems does
  # this change?
  # should check this fits
  result = mpf_get_d(a.addr)
  if result == 0.0 and mpf_cmp_d(a.addr,0.0) != 0:
    tooSmall
  if result == Inf:
    tooLarge 

proc toFloat*(a: var mpf_t): float =
  toFloatHelper(result) 
    do: raise newException(ValueError, "number too small"):
        raise newException(ValueError, "number too large")

proc `$`*(a: var mpf_t, base: cint = 10, n_digits = 10): string =
  var outOfRange = false
  var floatVal: float
  
  #May have to remove this due to system specific behaviour
  toFloatHelper(floatVal) 
    do: outOfRange = true:
        outOfRange = true
  
  # case: fits in float      
  if base == 10 and not outOfRange:
    return $floatVal
  
  var exp: mp_exp_t
  # +1 for possible minus sign
  var str = newString(n_digits + 1)
  let coeff = $mpf_get_str(str,exp.addr,base,n_digits,a.addr)
  if (exp != 0):
    return coeff & "e" & $exp
  if coeff == "":
    return "0.0"
  result = coeff
  
proc `==`*(a,b: var mpf_t): bool =
  return mpf_cmp(a.addr,b.addr) == 0
  
proc `<`*(a,b: var mpf_t): bool =
  return mpf_cmp(a.addr,b.addr) < 0

proc `<=`*(a,b: var mpf_t): bool =
  let t = mpf_cmp(a.addr,b.addr)
  t < 0 or t == 0

proc cmp*(a,b: var mpf_t): int =
  return mpf_cmp(a.addr,b.addr)
  
proc destroy*(a: var mpf_t) {.destructor.} =
  mpf_clear(a.addr)
  
converter convert*(a: mpz_t): mpf_t =
  result = init_mpf_t()
  var temp = a
  mpf_set_z(result.addr,temp.addr)
  
when isMainModule:
  proc testEq() =
    var t1 = new(mpz_t)
    var t2 = new(mpz_t)
    var t3 = new(mpz_t)
    
    discard mpz_init_set_str(t1[].addr,"123",10)
    discard mpz_init_set_str(t2[].addr,"123",10)
    discard mpz_init_set_str(t3[].addr,"124",10)
    assert t1[] == t2[]
    assert t2[] != t3[]
    assert t1[] < t3[]
    assert t3[] > t1[]
    assert t3[].cmp(t1[]) > 0
    
  proc testAlloc =
    var t = alloc_mpz_t()
    assert (($t) == "0")
    dealloc_mpz_t(t)
    
  proc testFloatConv =
    var t = 123.456.toMpf
    #echo 123.4.mpf_t # converter doesn't work
    assert ($t == "123.456")
  
  proc testToPtr =
    var t: mpz_t = 0
    var t2: mpz_t = 5
    mpz_add(t,t2,t)
    assert ($t == "5")
    var f: mpf_t = 0.0
    var f2: mpf_t = 5.0
    mpf_add(f,f2,f)
    assert ($f == "5.0")

  proc testToFloat =
  
    var tooSmall = false
    try:
      var f = init_mpf_t("1e-11043")
      discard f.toFloat()
    except:
      var e = getCurrentException()
      assert e of ValueError
      tooSmall = true 
    assert(tooSmall)
    
    var tooLarge = false
    try:
      var f = init_mpf_t("1e1104367")
      echo f.toFloat()
    except:
      var e = getCurrentException()
      assert e of ValueError
      tooLarge = true     
    assert(tooLarge)
    
    # check we don't get an excpetion in the case of zero
    var f = init_mpf_t(0.0)
    discard f.toFloat()

  proc testLiteralHelpers =
    # test should stay alive whilst in scope
    let test = mpz_p(123)
    GC_fullcollect()
    assert($test == "123")
    
    var res: mpz_t = init_mpz_t(0)
    mpz_add(res.addr,mpz_p(5),mpz_p(19))
    
    # a bit clunky 
    assert res == mpz_p(24)[]
    
    
  testEq()
  testAlloc()
  testFloatConv()
  testToPtr()
  testToFloat()
  testLiteralHelpers()
