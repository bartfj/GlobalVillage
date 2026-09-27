import sys
sys.path.insert(0, r'd:\workspace\github_code\地球村\.trae\sdk\pylibs')
import qrcode
from PIL import Image, ImageDraw

img = qrcode.make('http://192.168.2.150:8000/v086.apk')
out = r'd:\workspace\github_code\地球村\.trae\apk_qr.png'
img.save(out)
print('QR SAVED', out)
