#!/bin/sh  
memodb=/tmp/db/memo_m.db
sqlite3 $memodb "$*" -header -column 

