#!/bin/bash

export DST=../../focuspoints.lrdevplugin/assets/imgs

`gm convert _focus_point_red-fat_center.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 $DST/center/red/normal.png`
`gm convert _focus_point_red_center.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 $DST/center/red/small.png`

for ((i = 0; i < 360; i += 5));
do
    `gm convert _focus_point_red_corner.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 $DST/corner/red/normal_$i.png`
    `gm convert _focus_point_red_corner-small.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 $DST/corner/red/small_$i.png`

    `gm convert _focus_point_red-fat_corner.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 $DST/corner/red/normal_fat_$i.png`
    `gm convert _focus_point_red-fat_corner-small.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 $DST/corner/red/small_fat_$i.png`

    `gm convert _focus_point_grey_corner.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 $DST/corner/grey/normal_$i.png`
    `gm convert _focus_point_grey_corner-small.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 $DST/corner/grey/small_$i.png`

    `gm convert _focus_point_black_corner.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 $DST/corner/black/normal_$i.png`
    `gm convert _focus_point_black_corner-small.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 $DST/corner/black/small_$i.png`

    `gm convert _focus_point_yellow_corner.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 $DST/corner/yellow/normal_$i.png`
    `gm convert _focus_point_yellow_corner-small.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 $DST/corner/yellow/small_$i.png`
done
