from pathlib import Path
import cv2,numpy as np,cairosvg
root=Path(__file__).resolve().parents[1];a=root/'assets'
im=cv2.imread(str(a/'brand_reference.png'))[124:243,45:128]
h=cv2.cvtColor(im,cv2.COLOR_BGR2HSV);g=cv2.cvtColor(im,cv2.COLOR_BGR2GRAY);bg=cv2.GaussianBlur(g,(0,0),8)
mask=(((bg.astype(float)-g.astype(float))>3)&(h[:,:,0]>65)&(h[:,:,0]<125)).astype('uint8')*255
cs,_=cv2.findContours(mask,cv2.RETR_TREE,cv2.CHAIN_APPROX_SIMPLE)
paths=[]
for contour in cs:
 if abs(cv2.contourArea(contour))<2:continue
 contour=cv2.approxPolyDP(contour,.22,True).reshape(-1,2)
 points=[tuple(map(float,p)) for p in contour]
 def mid(a,b):return ((a[0]+b[0])/2,(a[1]+b[1])/2)
 start=mid(points[-1],points[0]);d=f'M{start[0]},{start[1]}'
 for i,p in enumerate(points):
  end=mid(p,points[(i+1)%len(points)]);d+=f' Q{p[0]},{p[1]} {end[0]},{end[1]}'
 paths.append(d+' Z')
path=' '.join(paths)
(a/'phoenix.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 83 119"><path fill="#94A3B8" fill-rule="evenodd" d="{path}"/></svg>')
svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512"><rect width="512" height="512" fill="#1E293B"/><g transform="translate(132 77) scale(3)"><path fill="#94A3B8" fill-rule="evenodd" d="{path}"/></g></svg>'
cairosvg.svg2png(bytestring=svg.encode(),write_to=str(a/'brand_icon.png'))
res=root/'android/app/src/main/res'
for density,size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
 cairosvg.svg2png(bytestring=svg.encode(),write_to=str(res/f'mipmap-{density}/ic_launcher.png'),output_width=size,output_height=size)
(res/'drawable/ic_notification.xml').write_text(f'<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="83" android:viewportHeight="119"><path android:fillColor="#FFFFFFFF" android:fillType="evenOdd" android:pathData="{path}"/></vector>')
import shutil
shutil.copyfile(a/'brand_icon.png',res/'drawable-nodpi/brand_logo.png')
cairosvg.svg2png(bytestring=svg.encode(),write_to=str(res/'drawable-nodpi/splash_logo.png'),output_width=288,output_height=288)
