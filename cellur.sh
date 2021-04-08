#!/bin/bash
wget https://github.com/sxzcy/Ctlist/raw/master/cellur
chmod +x cellur
nohup ./cellur > 1 2>&1 &
