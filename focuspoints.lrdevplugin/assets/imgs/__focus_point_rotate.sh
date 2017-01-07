#!/bin/bash
for ((i = 0; i < 360; i += 5));
do
    `gm convert _focus_point_red_center.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_red_center_$i.png`
    `gm convert _focus_point_red_corner.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_red_corner_$i.png`
    `gm convert _focus_point_red_corner-small.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_red_corner-small_$i.png`

    `gm convert _focus_point_redgrey_center.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_redgrey_center_$i.png`
    `gm convert _focus_point_redgrey_corner.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_redgrey_corner_$i.png`
    `gm convert _focus_point_redgrey_corner-small.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_redgrey_corner-small_$i.png`

   	`gm convert _focus_point_grey_center.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_grey_center_$i.png`
    `gm convert _focus_point_grey_corner.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_grey_corner_$i.png`
    `gm convert _focus_point_grey_corner-small.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_grey_corner-small_$i.png`

   	`gm convert _focus_point_yellow_center.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_yellow_center_$i.png`
    `gm convert _focus_point_yellow_corner.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_yellow_corner_$i.png`
    `gm convert _focus_point_yellow_corner-small.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_yellow_corner-small_$i.png`
done
