import serial, time

s = serial.Serial("COM6", 115200, timeout=0.5)
time.sleep(0.2)
s.read_all()

def cmd(c, wait=0.6):
    s.write((c + "\r").encode("ascii"))
    time.sleep(wait)
    out = s.read_all().decode("ascii", errors="replace")
    print(f">>> {c}\n{out.strip()}\n")
    return out

cmd("")
cmd("*HELP", 0.8)
cmd('TIME=0 : ?&A002=100 : PRINT "T_1SEC=";TIME', 1.5)
cmd('TIME=0 : FOR I=1 TO 2000 : NEXT : PRINT "T_LOOP=";TIME', 1.2)
cmd("*BG ON", 0.5)
cmd('?&A020=0 : PRINT "SP0_A:";?&A021;",";?&A023;" ACT=";?&A025', 0.5)
time.sleep(0.5)
cmd('?&A020=0 : PRINT "SP0_B:";?&A021;",";?&A023;" ACT=";?&A025', 0.5)
cmd("*CAT", 0.8)
cmd("?&70=0 : P%=&900 : [OPT 2 : INC &70 : RTS :] : ?&2F6=0 : ?&2F7=&09", 0.6)
time.sleep(0.5)
cmd('PRINT "BG_COUNTER=";?&70 : ?&2F7=0', 0.5)
cmd("*BG OFF", 0.5)
cmd("*BG ON", 0.5)
s.close()
