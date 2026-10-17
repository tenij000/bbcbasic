org $b000

include_LANG_HEADER=FALSE        \ 35 bytes
include_AUTO=FALSE               \ 54 bytes
include_LOADSAVECHAIN=TRUE       \ 103 bytes
include_OSCLI=TRUE               \ 34 bytes
                                 \ 14 byte shared
include_RANDOMACCESS=TRUE        \ 443 bytes

.rom_start

include "SD_MOS.asm"

ORG $c000

.ENTER_BASIC

WRCHV=0                          \ Use JMP $FFEE directly

include "Basic2.asm"
include "SBC_MOS.asm"

.rom_end

SAVE rom_start, rom_end
