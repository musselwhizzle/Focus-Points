#!/bin/bash
for ((i = 0; i < 360; i += 5));
do
    `gm convert _focus_point_red_center.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_red_center_$i.png`
    `gm convert _focus_point_red_corner.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_red_corner_$i.png`
    `gm convert _focus_point_red_corner-small.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_red_corner-small_$i.png`

    `gm convert _focus_point_red-fat_center.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_red-fat_center_$i.png`
    `gm convert _focus_point_red-fat_corner.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_red-fat_corner_$i.png`
    `gm convert _focus_point_red-fat_corner-small.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_red-fat_corner-small_$i.png`

    `gm convert _focus_point_grey_center.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_grey_center_$i.png`
    `gm convert _focus_point_grey_corner.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_grey_corner_$i.png`
    `gm convert _focus_point_grey_corner-small.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_grey_corner-small_$i.png`

    `gm convert _focus_point_black_center.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_black_center_$i.png`
    `gm convert _focus_point_black_corner.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_black_corner_$i.png`
    `gm convert _focus_point_black_corner-small.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_black_corner-small_$i.png`

    `gm convert _focus_point_yellow_center.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_yellow_center_$i.png`
    `gm convert _focus_point_yellow_corner.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_yellow_corner_$i.png`
    `gm convert _focus_point_yellow_corner-small.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -type TrueColor -quality 100 focus_point_yellow_corner-small_$i.png`
done

# Mirrored images
for ((i = 0; i < 360; i += 5));
do
    `gm convert _focus_point_red_center.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -flop -type TrueColor -quality 100 focus_point_red_center_$i-mirrored.png`
    `gm convert _focus_point_red_corner.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -flop -type TrueColor -quality 100 focus_point_red_corner_$i-mirrored.png`
    `gm convert _focus_point_red_corner-small.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -flop -type TrueColor -quality 100 focus_point_red_corner-small_$i-mirrored.png`

    `gm convert _focus_point_red-fat_center.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -flop -type TrueColor -quality 100 focus_point_red-fat_center_$i-mirrored.png`
    `gm convert _focus_point_red-fat_corner.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -flop -type TrueColor -quality 100 focus_point_red-fat_corner_$i-mirrored.png`
    `gm convert _focus_point_red-fat_corner-small.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -flop -type TrueColor -quality 100 focus_point_red-fat_corner-small_$i-mirrored.png`

    `gm convert _focus_point_grey_center.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -flop -type TrueColor -quality 100 focus_point_grey_center_$i-mirrored.png`
    `gm convert _focus_point_grey_corner.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -flop -type TrueColor -quality 100 focus_point_grey_corner_$i-mirrored.png`
    `gm convert _focus_point_grey_corner-small.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -flop -type TrueColor -quality 100 focus_point_grey_corner-small_$i-mirrored.png`

    `gm convert _focus_point_black_center.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -flop -type TrueColor -quality 100 focus_point_black_center_$i-mirrored.png`
    `gm convert _focus_point_black_corner.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -flop -type TrueColor -quality 100 focus_point_black_corner_$i-mirrored.png`
    `gm convert _focus_point_black_corner-small.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -flop -type TrueColor -quality 100 focus_point_black_corner-small_$i-mirrored.png`

    `gm convert _focus_point_yellow_center.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -flop -type TrueColor -quality 100 focus_point_yellow_center_$i-mirrored.png`
    `gm convert _focus_point_yellow_corner.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -flop -type TrueColor -quality 100 focus_point_yellow_corner_$i-mirrored.png`
    `gm convert _focus_point_yellow_corner-small.png -background transparent -gravity center -extent 45x45+0+0 -gravity center -rotate -$i -gravity center -extent 45x45+0+0 -flop -type TrueColor -quality 100 focus_point_yellow_corner-small_$i-mirrored.png`
done
