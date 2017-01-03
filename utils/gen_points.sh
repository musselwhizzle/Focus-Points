#!/bin/bash

echo "focusPointDimens = {300, 250}"

#
# left grouping
#
x=1725
y=1750
dx=350
dy=305

colNames=( {A..E} )

for col in {0..4}
do
  for row in {0..3}
  do
    myx=$((x+row*dx))
    myy=$((y+col*dy))
    prettyRow=$((row+1))

    if [[ $col == 0 ]] || [[ $col == 4 ]] 
    then
      if [[ $row > 2 ]] ; then continue ; fi
      myx=$((myx+dx))
    fi

    echo "${colNames[$col]}$prettyRow = {$myx, $myy}"
  done
done

#
# right grouping
#
x=4375
y=1750
dx=350
dy=305

colNames=( {A..E} )

for col in {0..4}
do
  for row in {0..3}
  do
    myx=$((x+row*dx))
    myy=$((y+col*dy))
    prettyRow=$((row+7))

    if [[ $col == 0 ]] || [[ $col == 4 ]]
    then
      if [[ $row == 3 ]] ; then continue ; fi
    else
      prettyRow=$((prettyRow+1))
    fi

    echo "${colNames[$col]}$prettyRow = {$myx, $myy}"
  done
done


#
# middle grouping
#
x=3190
y=1650
dx=375
dy=355

colNames=( {A..E} )

for col in {0..4}
do
  for row in {0..2}
  do
    myx=$((x+row*dx))
    myy=$((y+col*dy))
    prettyRow=$((row+4))

    if [[ $col != 0 ]] && [[ $col != 4 ]]
    then
      prettyRow=$((prettyRow+1))
    fi

    echo "${colNames[$col]}$prettyRow = {$myx, $myy}"
  done
done
