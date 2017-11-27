#!/usr/bin/env python

from pwn import *
import sys, os

wordSz = 4
hwordSz = 2
bits = 32
PIE = 0

def leak(address, size):
   with open('/proc/%s/mem' % pid) as mem:
      mem.seek(address)
      return mem.read(size)

def findModuleBase(pid, mem):
   name = os.readlink('/proc/%s/exe' % pid)
   with open('/proc/%s/maps' % pid) as maps: 
      for line in maps:
         if name in line:
            addr = int(line.split('-')[0], 16)
            mem.seek(addr)
            if mem.read(4) == "\x7fELF":
               bitFormat = u8(leak(addr + 4, 1))
               if bitFormat == 2:
                  global wordSz
                  global hwordSz
                  global bits
                  wordSz = 8
                  hwordSz = 4
                  bits = 64
               return addr
   log.failure("Module's base address not found.")
   sys.exit(1)

def findIfPIE(addr):
   e_type = u8(leak(addr + 0x10, 1))
   if e_type == 3:
      return addr
   else:
      return 0

def findPhdr(addr):
   if bits == 32:
      e_phoff = u32(leak(addr + 0x1c, wordSz).ljust(4, '\0'))
   else:
      e_phoff = u64(leak(addr + 0x20, wordSz).ljust(8, '\0'))
   return e_phoff + addr

def findDynamic(Elf32_Phdr, moduleBase, bitSz):
   if bitSz == 32:
      i = -32
      p_type = 0
      while p_type != 2:
         i += 32
         p_type = u32(leak(Elf32_Phdr + i, wordSz).ljust(4, '\0'))
      return u32(leak(Elf32_Phdr + i + 8, wordSz).ljust(4, '\0')) + PIE
   else:
      i = -56
      p_type = 0
      while p_type != 2:
         i += 56
         p_type = u64(leak(Elf32_Phdr + i, hwordSz).ljust(8, '\0'))
      return u64(leak(Elf32_Phdr + i + 16, wordSz).ljust(8, '\0')) + PIE

def findDynTable(Elf32_Dyn, table, bitSz):
   p_val = 0
   if bitSz == 32:
      i = -8
      while p_val != table:
         i += 8
         p_val = u32(leak(Elf32_Dyn + i, wordSz).ljust(4, '\0'))
      return u32(leak(Elf32_Dyn + i + 4, wordSz).ljust(4, '\0'))
   else:
      i = -16
      while p_val != table:
         i += 16
         p_val = u64(leak(Elf32_Dyn + i, wordSz).ljust(8, '\0'))
      return u64(leak(Elf32_Dyn + i + 8, wordSz).ljust(8, '\0'))

def getPtr(addr, bitSz):
   with open('/proc/%s/maps' % sys.argv[1]) as maps: 
      for line in maps:
         if 'libc-' in line and 'r-x' in line:
            libc = line.split(' ')[0].split('-')
   i = 3
   while True:
      if bitSz == 32:
         gotPtr = u32(leak(addr + i*4, wordSz).ljust(4, '\0'))
      else:
         gotPtr = u64(leak(addr + i*8, wordSz).ljust(8, '\0'))
      if (gotPtr > int(libc[0], 16)) and (gotPtr < int(libc[1], 16)):
         return gotPtr
      else:
         i += 1
         continue

def findLibcBase(ptr):
   ptr &= 0xfffffffffffff000
   while leak(ptr, 4) != "\x7fELF":
      ptr -= 0x1000
   return ptr

def findSymbol(strtab, symtab, symbol, bitSz):
   if bitSz == 32:
      i = -16
      while True:
         i += 16
         st_name = u32(leak(symtab + i, 2).ljust(4, '\0'))
         if leak( strtab + st_name, len(symbol)+1 ).lower() == (symbol.lower() + '\0'):
            return u32(leak(symtab + i + 4, 4).ljust(4, '\0'))
   else:
      i = -24
      while True:
         i += 24
         st_name = u64(leak(symtab + i, 4).ljust(8, '\0'))
         if leak( strtab + st_name, len(symbol)).lower() == (symbol.lower()):
            return u64(leak(symtab + i + 8, 8).ljust(8, '\0'))

def lookup(pid, symbol):
   with open('/proc/%s/mem' % pid) as mem:
      moduleBase = findModuleBase(pid, mem)
   log.info("Module's base address:................. " + hex(moduleBase))

   global PIE
   PIE = findIfPIE(moduleBase)
   if PIE:
      log.info("Binary is PIE enabled.")
   else:
      log.info("Binary is not PIE enabled.")

   modulePhdr = findPhdr(moduleBase)
   log.info("Module's Program Header:............... " + hex(modulePhdr))

   moduleDynamic = findDynamic(modulePhdr, moduleBase, bits) 
   log.info("Module's _DYNAMIC Section:............. " + hex(moduleDynamic))

   moduleGot = findDynTable(moduleDynamic, 3, bits)
   log.info("Module's GOT:.......................... " + hex(moduleGot))

   libcPtr = getPtr(moduleGot, bits)
   log.info("Pointer from GOT to a function in libc: " + hex(libcPtr))

   libcBase = findLibcBase(libcPtr)
   log.info("Libc's base address:................... " + hex(libcBase))

   libcPhdr = findPhdr(libcBase)
   log.info("Libc's Program Header:................. " + hex(libcPhdr))

   PIE = findIfPIE(libcBase)
   libcDynamic = findDynamic(libcPhdr, libcBase, bits)
   log.info("Libc's _DYNAMIC Section:............... " + hex(libcDynamic))

   libcStrtab = findDynTable(libcDynamic, 5, bits)
   log.info("Libc's DT_STRTAB Table:................ " + hex(libcStrtab))

   libcSymtab = findDynTable(libcDynamic, 6, bits)
   log.info("Libc's DT_SYMTAB Table:................ " + hex(libcSymtab))

   symbolAddr = findSymbol(libcStrtab, libcSymtab, symbol, bits)
   log.success("%s loaded at address:.............. %s" % (symbol, hex(symbolAddr + libcBase)))


if __name__ == "__main__":
   log.info("Manual usage of pwnlib.dynelf")
   if len(sys.argv) == 3:
      pid = sys.argv[1]
      symbol = sys.argv[2]
      lookup(pid, symbol)
   else:
      log.failure("Usage: %s PID SYMBOL" % sys.argv[0])
