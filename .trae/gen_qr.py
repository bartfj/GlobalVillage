from pathlib import Path

import qrcode

url = 'http://192.168.0.111:8080/earthvillage-0.8.52.apk'
out = Path(__file__).with_name('apk_qr.png')
qrcode.make(url).save(out)
print('QR SAVED', out, url)
