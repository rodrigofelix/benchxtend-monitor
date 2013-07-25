#!/bin/bash
CPU=$(top -bn 2 -d.5 | grep "Cpu" | grep -v grep | tail -n1 | awk '{sub(/%us,/, "", $2); sub(/%sy,/, "", $3); print ($2 + $3) / 100}')
MEM=$(top -bn 2 -d.5 | grep "Mem" | grep -v grep | tail -n1 | awk '{gsub(/k/, ""); print $4 / $2}')
echo $CPU,$MEM