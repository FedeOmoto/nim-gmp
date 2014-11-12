import macros
import strutils
import tables

const file = "gmp.nim"
const dynlib = "libgmp"
let symbols {.compileTime.} = gorge("nm -A -D /usr/lib/libgmp.so")
var libFuncs {.compileTime.} = newSeq[string]() # stores gmp dll function names

static:
  for line in symbols.split("\n"):
    var t = line.split()
    libFuncs.add t[t.high].strip


proc mkVar(properType: string): PNimrodNode {.compileTime.} =
  newNimNode(nnkVarTy).add(ident(properType))

proc mkLet(properType: string): PNimrodNode {.compileTime.} =
  ident(properType)
  

# src ptrs are const so map to let
# else map to var
# need to set mpz_t etc. to byref with pragma
let mappings {.compileTime.} = {
  "mpz_srcptr" : mkLet "mpz_t",
  "mpz_ptr" : mkVar "mpz_t",
  "mpf_srcptr" : mkLet "mpf_t",
  "mpf_ptr" : mkVar "mpf_t",
  "mpq_srcptr" : mkLet "mpq_t",
  "mpq_ptr" : mkVar "mpq_t",
  "mp_ptr" : mkVar "mp_limb_t", # byref doesn't work for clong so should always be var
  "mp_srcptr" : mkVar "mp_limb_t", 
}.toTable

proc mkPragma(a: varargs[string]): PNimrodNode {.compileTime.} =
  result = newNimNode(nnkPragma)
  for str in a:
    result.add(ident(str))
  

let stdPrag {.compileTime.} = mkPragma("pure", "packed")
let byrefPrag {.compileTime.} = mkPragma("byref", "pure", "packed")

let specialTypes {.compileTime.} = {
  "mm_mpz_struct": byrefPrag,
  "mm_mpf_struct": byrefPrag,
  "mm_mpq_struct": byrefPrag,
}.toTable


let oldCodeTxt {.compileTime.} = slurp(file)
var oldCode {.compileTime.} = parseStmt(oldCodeTxt)

proc getDynlibName(name: string): string {.compileTime.} =
  result = ""
  for func in libFuncs:
    #if nameInHeader in func: # too many iterations
   if func.endsWith name:
      return func 
      
macro fix_types(): stmt =
  ## changes pragmas from header style to dynlib style
  var newCode = oldCode.copy()
  var newTypeSection: PNimrodNode
  var index = 0
  for child in oldCode.children:
    if child.kind == nnkTypeSection:
      newTypeSection = child.copy()
      var newTypeDef: PNimrodNode
      var typeDefIndex = -1
      for typChild in child.children:
         inc typeDefIndex
         if typChild.kind == nnkTypeDef:
          newTypeDef = typChild.copy()
          var pragmaIndex = -1
          var pragExpr = newTypeDef.findChild((inc pragmaIndex; it.kind == nnkPragmaExpr))
          if pragExpr == nil: continue
          
          # this assumes it's exported (I think)
          let post = pragExpr.findChild(it.kind == nnkPostfix)
          if post == nil: continue
          var name = $post[1]
          
          # change pragmas
          if specialTypes.hasKey(name):
            pragExpr[1] = specialTypes[name]
            newTypeDef[0] = pragExpr
          elif typChild[2].kind == nnkObjectTy:
            pragExpr[1] = stdPrag
            newTypeDef[0] = pragExpr
          else:
            # remove pragma - moves postfix node to pragExpr position 
            newTypeDef[0] = post
         
         # remove pragmas from fields of objects
         if typChild[2].kind == nnkObjectTy:
          var recList = newTypeDef[2].findChild(it.kind == nnkRecList)
          for i in 0.. <reclist.len:
            var it = recList[i]
            if it.kind == nnkIdentDefs:
              if it[0].kind == nnkPragmaExpr:
                # pragma present, remove
                reclist[i][0] = it[0][0] # moves identifer to pragExpr position
         newTypeSection[typeDefIndex] = newTypeDef
         #echo treeRepr newTypeSection[typeDefIndex]
         #echo treeRepr newTypeDef
    else:
      discard
    if newTypeSection != nil:
      #echo repr newTypeSection
      newCode[index] = newTypeSection
      newTypeSection = nil
    inc index
  # swap to new code
  oldCode = newCode

macro fix_importc(): stmt =
  ## modifies oldCode
  var newCode = newStmtList()
  for child in oldCode.children:
    if child.kind == nnkProcDef:
      var procDef = child.copy()
      let pragma = child.findChild(it.kind == nnkPragma)
      var procName: string
      var pragCopy = pragma.copy
      for index in 0 .. <pragma.len:
        let it = pragma[index]
        #new colonExpr:
        var col = pragCopy[index]
        if it.kind == nnkExprColonExpr:
          if $(it[0]) == "importc":
          
            # strip leading _ (these are the inline versions?)
            let headerName = it[1].strVal
            if headerName.startsWith("_"):
              procName = headerName[1..headerName.high]
            else:
              procName = headerName
                        
            var t = getDynlibName(procName)
            if t == "":
              # this means we couldn't find function
              error("CAN'T FIND SYMBOL: " & procDef.repr)
            # importc: t
            col[1] = newStrLitNode(t)
          elif $(it[0]) == "header":
            col[0] = ident("dynlib")
            col[1] = ident(dynlib)
      pragCopy.add ident("cdecl")    
      procDef[4] = pragCopy
      var exportedName = postfix(ident(procName),"*")
      procDef[0] = exportedName     
      newCode.add procDef
    else:
      newCode.add child
  # swap to new code
  oldCode = newCode

macro nimify_params(): stmt =
  ## modifies oldCode
  var newCode = newStmtList()
  for child in oldCode.children:
    if child.kind == nnkProcDef:
      var keyFound = false # flag to indicate we should generate a new proc
      let params = child.findChild(it.kind == nnkFormalParams)
      let newParams = params.copy()
      # loop over all identDefs in param
      for index in 0 .. <params.len:
        let it = params[index]
        if it.kind == nnkIdentDefs:
          # identDefs contain info about params
          var identIndex = -1
          let identDefs = params.findChild((inc identIndex; identIndex == index and it.kind == nnkIdentDefs))
          # 1th ident refers to object type
          if len(identDefs) > 1 and (identDefs[1].kind == nnkIdent or identDefs[1].kind == nnkPtrTy):
            let paramType = repr identDefs[1] # string value
            if mappings.hasKey paramType:
              keyFound = true
              let val = mappings[paramType]
              var identDefsMod = identDefs.copy()
              identDefsMod[1] = val.copy()
              newParams[index] = identDefsMod
      var procDef = child.copy()
      procdef[3] = newParams
      newCode.add child
      if child.repr != procDef.repr:
        newCode.add procDef
      elif keyFound:
        warning("generated dupe")
        echo(child.repr)
    else:
      newCode.add child
  # swap to new code
  oldCode = newCode

macro print(): stmt =
  result = newStmtList()
  for child in oldCode.children:
    result.add newCall("echo", child.toStrLit)        


fix_types()  
fix_importc()
nimify_params()
print()


discard """ static:
  if mappings.hasKey "mpz_srcptr":
    echo "ok"
  else:
    echo "not ok"
 """
