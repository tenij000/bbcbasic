cx = 320
cy = 180
sx0_raw = cx
sy0_raw = cy
sx1_raw = cx + 100

r = abs(sx1_raw - sx0_raw)
err = 3 - (2 * r)
x = 0
y = r

points = []
while x <= y:
    points.append((x, y))
    if err < 0:
        err = err + (x << 2) + 6
    else:
        err = err + ((x - y) << 2) + 10
        y = y - 1
    x = x + 1

for p in points:
    print(p)
