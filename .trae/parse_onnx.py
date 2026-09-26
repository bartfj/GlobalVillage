import sys

path = sys.argv[1]
data = open(path, 'rb').read(8192)


def rd_varint(b, i):
    r = 0
    s = 0
    while True:
        x = b[i]
        i += 1
        r |= (x & 0x7F) << s
        s += 7
        if not x & 0x80:
            return r, i


i = 0
while i < len(data):
    tag, i = rd_varint(data, i)
    fld, wire = tag >> 3, tag & 7
    if wire == 0:
        v, i = rd_varint(data, i)
        print('field %d varint %d' % (fld, v))
    elif wire == 2:
        ln, i = rd_varint(data, i)
        sub = data[i:i + ln]
        if fld == 8:
            d = ''
            v = None
            j = 0
            while j < len(sub):
                t2, j = rd_varint(sub, j)
                f2, w2 = t2 >> 3, t2 & 7
                if w2 == 2:
                    l2, j = rd_varint(sub, j)
                    d = sub[j:j + l2].decode()
                    j += l2
                elif w2 == 0:
                    v, j = rd_varint(sub, j)
            print('opset_import domain=%r version=%s' % (d, v))
        elif fld == 2:
            print('field 2 str=%r' % sub.decode(errors='replace'))
        else:
            print('field %d len=%d (skipped)' % (fld, ln))
            if fld == 7:
                break
        i += ln
    else:
        print('wire %d fld %d stop' % (wire, fld))
        break
