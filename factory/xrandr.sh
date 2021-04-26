#!/bin/sh

xrandr --addmode VGA1 1600x1200
xrandr --output VGA0 --mode 1600x1200
xrandr --output VGA1 --mode 1600x1200
xrandr --output VGA1 --right-of VGA0

