from PIL import Image, ImageDraw, ImageFont, ImageFilter
import arabic_reshaper
from bidi.algorithm import get_display
from pathlib import Path
import math, random
W,H=1920,1080
OUT=Path('docs')
REG='/usr/share/fonts/opentype/fonts-hosny-amiri/Amiri-Regular.ttf'
BOLD='/usr/share/fonts/opentype/fonts-hosny-amiri/Amiri-Bold.ttf'
LOGO='assets/mithaq2-icon-192.png'

def rtl(s): return get_display(arabic_reshaper.reshape(s))
def font(path,size): return ImageFont.truetype(path,size)
def txt(d,xy,s,size,fill,anchor='ra',bold=False):
    d.text(xy,rtl(s),font=font(BOLD if bold else REG,size),fill=fill,anchor=anchor)
def round_rect(d,box,r,fill,outline=None,width=1): d.rounded_rectangle(box,radius=r,fill=fill,outline=outline,width=width)
def bg():
    im=Image.new('RGB',(W,H),(3,18,14)); px=im.load()
    for y in range(H):
      for x in range(W):
        dx=(x-1320)/1000; dy=(y-300)/800; g=max(0,1-math.sqrt(dx*dx+dy*dy))
        px[x,y]=(int(3+8*g),int(20+42*g),int(15+28*g))
    glow=Image.new('RGBA',(W,H),(0,0,0,0)); gd=ImageDraw.Draw(glow)
    gd.ellipse((1050,-100,1750,600),fill=(35,123,84,80)); gd.ellipse((-250,720,450,1350),fill=(214,182,108,30)); glow=glow.filter(ImageFilter.GaussianBlur(55)); im=Image.alpha_composite(im.convert('RGBA'),glow)
    d=ImageDraw.Draw(im)
    for y in range(680,1180,62):
      alpha=int(38*max(0,min(1,(y-680)/450))); d.line((0,y,W,y),fill=(214,182,108,alpha),width=1)
    for x in range(-400,2400,80): d.line((960+(x-960)*.2,680,x,1080),fill=(214,182,108,30),width=1)
    return im

def header(im):
    d=ImageDraw.Draw(im); logo=Image.open(LOGO).convert('RGBA').resize((70,70))
    im.alpha_composite(logo,(90,50)); txt(d,(180,82),'میثاق ۲',34,(244,234,213,255),anchor='lm',bold=True); txt(d,(1830,82),'سامانه رسمی ثبت گزارش صوتی',25,(214,182,108,255),anchor='rm'); d.line((90,145,1830,145),fill=(214,182,108,100),width=2)

def phone(scene):
    p=Image.new('RGBA',(570,900),(0,0,0,0)); d=ImageDraw.Draw(p)
    round_rect(d,(18,18,552,882),68,(12,28,23,255),outline=(214,182,108,150),width=3); round_rect(d,(38,45,532,855),52,(244,234,213,255)); round_rect(d,(200,45,370,80),18,(12,28,23,255));
    d=ImageDraw.Draw(p); logo=Image.open(LOGO).convert('RGBA').resize((42,42)); p.alpha_composite(logo,(72,105)); txt(d,(130,126),'میثاق ۲',22,(18,59,46,255),anchor='lm',bold=True); txt(d,(490,126),'ثبت گزارش',18,(85,115,97,255),anchor='rm'); d.line((72,160,498,160),fill=(180,195,181,255),width=2)
    if scene in [1,2]:
      txt(d,(490,218),'ثبت گزارش جدید',34,(18,59,46,255),anchor='ra',bold=True)
      for y,label,value in [(275,'عنوان گزارش *','ثبت گزارش جلسه'),(380,'سطح فوریت *','ضروری')]:
        txt(d,(490,y),label,17,(36,76,61,255),anchor='ra',bold=True); round_rect(d,(72,y+16,498,y+70),12,(255,253,248,255),outline=(201,213,200,255),width=2); txt(d,(470,y+43),value,17,(22,55,44,255),anchor='ra')
      round_rect(d,(72,495,498,750),20,(226,238,229,255)); txt(d,(470,535),'ضبط صدای شما',18,(36,76,61,255),anchor='ra',bold=True)
      heights=[25,48,76,42,70,50,30,62,45,78,49,32]
      for i,h in enumerate(heights): d.rounded_rectangle((122+i*27,610-h//2,134+i*27,610+h//2),radius=6,fill=(27,99,72,255))
      if scene==1: round_rect(d,(72,770,270,824),14,(18,59,46,255)); txt(d,(171,797),'در حال ضبط',20,(255,255,255,255),anchor='mm',bold=True)
      else: txt(d,(470,790),'سنجاق عکس در صورت نیاز',17,(86,114,99,255),anchor='ra')
    elif scene==3:
      txt(d,(490,250),'گزارش شما دریافت شد',33,(18,59,46,255),anchor='ra',bold=True); d.ellipse((210,340,360,490),fill=(223,236,225,255)); txt(d,(285,418),'✓',80,(40,96,73,255),anchor='mm',bold=True); txt(d,(490,560),'گزارش با موفقیت ارسال شد.',21,(113,132,119,255),anchor='ra'); round_rect(d,(170,630,400,700),16,(226,238,229,255)); txt(d,(285,665),'M2-جلسه',25,(18,59,46,255),anchor='mm',bold=True)
    return p.rotate(7,resample=Image.Resampling.BICUBIC,expand=True)

def add_phone(im,sc,x=175,y=155): im.alpha_composite(phone(sc),(x,y))
def scene0():
 im=bg();header(im);d=ImageDraw.Draw(im);txt(d,(1760,330),'اعتماد، از یک گزارش روشن آغاز می‌شود',28,(214,182,108,255),anchor='ra');txt(d,(1760,440),'از این به بعد ما',74,(244,234,213,255),anchor='ra',bold=True);txt(d,(1760,540),'معتمد شماییم،',74,(214,182,108,255),anchor='ra',bold=True);txt(d,(1760,650),'میثاق ۲',82,(244,234,213,255),anchor='ra',bold=True);d.rounded_rectangle((1300,710,1490,718),4,fill=(214,182,108,255));txt(d,(1760,805),'ثبت گزارش صوتی؛ سریع، روشن و امن.',29,(197,217,201,255),anchor='ra');add_phone(im,1,140,155);return im

def scene_text(im,step,lines):
 d=ImageDraw.Draw(im);txt(d,(1780,330),step,28,(214,182,108,255),anchor='ra');y=450
 for i,line in enumerate(lines):txt(d,(1780,y+i*90),line,56,(244,234,213,255) if i%2==0 else (214,182,108,255),anchor='ra',bold=True)

def scene4():
 im=bg();header(im);d=ImageDraw.Draw(im);txt(d,(960,340),'میثاق ۲',32,(214,182,108,255),anchor='mm');txt(d,(960,480),'از این به بعد ما معتمد شماییم',75,(244,234,213,255),anchor='mm',bold=True);d.rounded_rectangle((865,560,1055,568),4,fill=(214,182,108,255));txt(d,(960,660),'گزارش خود را روشن، سریع و امن ثبت کنید.',31,(197,217,201,255),anchor='mm');logo=Image.open(LOGO).convert('RGBA').resize((165,165));im.alpha_composite(logo,(877,760));return im
for i in range(5):
 if i==0: im=scene0()
 elif i==1: im=bg();header(im);add_phone(im,1,100,150);scene_text(im,'مرحله اول',['گزارش را','در چند ثانیه','آماده کنید.'])
 elif i==2: im=bg();header(im);add_phone(im,2,100,150);scene_text(im,'مرحله دوم',['صدای شما،','جزئیات واقعی','گزارش است.'])
 elif i==3: im=bg();header(im);add_phone(im,3,90,150);d=ImageDraw.Draw(im);round_rect(d,(1170,185,1715,320),22,(22,61,48,245),outline=(214,182,108,180),width=2);txt(d,(1675,230),'گزارش جدید ثبت شد',24,(244,234,213,255),anchor='ra',bold=True);txt(d,(1675,275),'یک گزارش صوتی برای بررسی آماده است.',17,(197,217,201,255),anchor='ra');scene_text(im,'مرحله سوم',['اطمینان،','در هر ارسال','همراه شماست.'])
 else: im=scene4()
 im.convert('RGB').save(OUT/f'premium-keyframe-{i}.png',quality=95)
