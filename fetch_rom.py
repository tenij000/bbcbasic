import urllib.request
import re

url = 'https://raw.githubusercontent.com/douggilliland/MultiComp/master/MultiComp-GS_Files/ROMS/6502/M6502_BASIC_ROM.vhd'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    res = urllib.request.urlopen(req).read().decode('utf-8')
    matches = re.findall(r'x\"([0-9A-Fa-f]{2})\"', res)
    print(f'Gevonden bytes: {len(matches)}')
    with open('src/ehbasic.hex', 'w') as f:
        # EhBASIC expects an 8KB ROM typically. The VHDL file defines the ROM.
        for m in matches:
            f.write(m + '\n')
    print('Succesvol ehbasic.hex gegenereerd.')
except Exception as e:
    print('Fout:', e)
