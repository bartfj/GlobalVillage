from pathlib import Path

import qrcode

url = 'http://192.168.1.5:8080/earthvillage-latest.apk'
out = Path(__file__).with_name('apk_qr.png')
qrcode.make(url).save(out)
print('QR SAVED', out, url)
