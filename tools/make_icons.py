# Draws the app icon and writes every Android and iOS size.
# Usage: python3 tools/make_icons.py <preview-dir> [repo-root]
import sys, os
from PIL import Image, ImageDraw
TEAL=(11,107,99,255); MINT=(158,217,208,255); WHITE=(255,255,255,255); INK=(11,61,57,255)
S=4096  # supersampled canvas

def capsule(size, white_only=False):
    """Diagonal capsule on transparent ground, drawn in a size x size box."""
    im=Image.new('RGBA',(S,S),(0,0,0,0)); d=ImageDraw.Draw(im)
    L, W = S*0.80, S*0.34          # capsule length and width
    cx=cy=S/2
    x0, x1 = cx-L/2, cx+L/2; y0, y1 = cy-W/2, cy+W/2
    r=W/2
    # left half white, right half mint, split at centre
    left=Image.new('RGBA',(S,S),(0,0,0,0)); dl=ImageDraw.Draw(left)
    dl.rounded_rectangle([x0,y0,x1,y1],radius=r,fill=WHITE)
    right=Image.new('RGBA',(S,S),(0,0,0,0)); dr=ImageDraw.Draw(right)
    dr.rounded_rectangle([x0,y0,x1,y1],radius=r,fill=WHITE if white_only else MINT)
    mask=Image.new('L',(S,S),0); ImageDraw.Draw(mask).rectangle([cx,0,S,S],fill=255)
    im=Image.composite(right,left,mask)
    if not white_only:
        # thin seam and a highlight on the white half
        d=ImageDraw.Draw(im)
        d.rectangle([cx-S*0.006,y0,cx+S*0.006,y1],fill=INK)
        d.rounded_rectangle([x0+W*0.28,y0+W*0.2,cx-W*0.35,y0+W*0.33],radius=W*0.07,fill=(255,255,255,0))
    else:
        d=ImageDraw.Draw(im)
        d.rectangle([cx-S*0.012,y0,cx+S*0.012,y1],fill=(0,0,0,0))
    im=im.rotate(45,resample=Image.BICUBIC)
    return im.resize((size,size),Image.LANCZOS)

def check_badge(im, size, white=False):
    pass

def full_icon(size, round_=False, square=False):
    """Legacy/iOS icon: teal ground + capsule."""
    bg=Image.new('RGBA',(S,S),(0,0,0,0)); d=ImageDraw.Draw(bg)
    if square: d.rectangle([0,0,S,S],fill=TEAL)
    elif round_: d.ellipse([0,0,S-1,S-1],fill=TEAL)
    else: d.rounded_rectangle([0,0,S-1,S-1],radius=S*0.22,fill=TEAL)
    cap=capsule(int(S*0.72))
    off=int(S*0.14); bg.alpha_composite(cap,(off,off))
    return bg.resize((size,size),Image.LANCZOS)

def adaptive_fg(size):
    """108dp canvas; content must sit in the centre 66dp."""
    im=Image.new('RGBA',(S,S),(0,0,0,0))
    cap=capsule(int(S*0.56)); off=int(S*0.22); im.alpha_composite(cap,(off,off))
    return im.resize((size,size),Image.LANCZOS)

out=sys.argv[1]
os.makedirs(out,exist_ok=True)
full_icon(1024,square=True).convert('RGB').save(f'{out}/ios_1024.png')
full_icon(512).save(f'{out}/preview_rounded.png')
full_icon(512,round_=True).save(f'{out}/preview_round.png')
capsule(256,white_only=True).save(f'{out}/notif.png')
adaptive_fg(432).save(f'{out}/fg.png')

def install(repo):
    res=f'{repo}/android/app/src/main/res'
    dens={'mdpi':1,'hdpi':1.5,'xhdpi':2,'xxhdpi':3,'xxxhdpi':4}
    for k,f in dens.items():
        d=f'{res}/mipmap-{k}'; os.makedirs(d,exist_ok=True)
        full_icon(int(48*f)).save(f'{d}/ic_launcher.png')
        full_icon(int(48*f),round_=True).save(f'{d}/ic_launcher_round.png')
        adaptive_fg(int(108*f)).save(f'{d}/ic_launcher_foreground.png')
        # Themed (monochrome) icon: same safe zone, white silhouette.
        mono=Image.new('RGBA',(S,S),(0,0,0,0)); mono.alpha_composite(capsule(int(S*0.56),white_only=True),(int(S*0.22),)*2)
        mono.resize((int(108*f),)*2,Image.LANCZOS).save(f'{d}/ic_launcher_monochrome.png')
        dd=f'{res}/drawable-{k}'; os.makedirs(dd,exist_ok=True)
        n=Image.new('RGBA',(S,S),(0,0,0,0)); n.alpha_composite(capsule(int(S*0.92),white_only=True),(int(S*0.04),)*2)
        n.resize((int(24*f),)*2,Image.LANCZOS).save(f'{dd}/ic_notification.png')
    os.makedirs(f'{res}/mipmap-anydpi-v26',exist_ok=True)
    xml='''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
'''
    for name in ['ic_launcher','ic_launcher_round']:
        open(f'{res}/mipmap-anydpi-v26/{name}.xml','w').write(xml)
    open(f'{res}/values/ic_launcher_background.xml','w').write('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#0B6B63</color>
</resources>
''')
    ios=f'{repo}/ios/Runner/Assets.xcassets/AppIcon.appiconset'
    big=full_icon(1024,square=True).convert('RGB')
    import re
    for fn in os.listdir(ios):
        m=re.match(r'Icon-App-([\d.]+)x[\d.]+@(\d)x\.png',fn)
        if m:
            px=round(float(m.group(1))*int(m.group(2)))
            big.resize((px,px),Image.LANCZOS).save(f'{ios}/{fn}')

if len(sys.argv)>2: install(sys.argv[2])
