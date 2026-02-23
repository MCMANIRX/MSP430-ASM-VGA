import cv2 as cv
import sys
import numpy as np
import platform
if len(sys.argv) <= 1:
    print("no img given")
    
tokens = []
if platform.system() == "Windows":
    tokens = sys.argv[1].split('\\')  
else:
    tokens = sys.argv[1].split('/')  

label = tokens[len(tokens)-1].split(".")[0]


img = cv.imread(sys.argv[1])
h,w,c = img.shape
colors = []


print(label)

for row in range(0,h):
    str_ = '\t.byte '
    for col in range(0,w):
        pixel = img[row,col]
        pixel = pixel[0] << 16 | pixel[1] << 8 | pixel[2]
        if pixel not in colors:      
            colors.append(pixel)
            pixel = len(colors)-1
        else:
            pixel = colors.index(pixel,0,len(colors))
        str_ += str(pixel)+", "
    str_ = str_.rstrip(', ')
    print(str_)

