#!/bin/bash
for ((i = 0; i < 360; i += 5));
do
    `gm convert focus_point.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_$i.png`
done
