#!/bin/bash
wget https://github.com/sxzcy/Ctlist/raw/master/cell
chmod +x cell
nohup ./cell > 1 2>&1 &
