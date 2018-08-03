#!/bin/sh
. ./init_template_lib.sh
tbname=macgroup
keyname=macgid

#drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		$keyname	integer 	primary key default 0, \
		macgrpname	char(64) 	not null unique default '', \
		macgrpdesc 	char(128) 	not null default '', \
		ranges 		text	 	not null default '{}', \
		ext		text		\
	)"
drop_mysql_disk_table $tbname
create_mysql_disk_table "create table $tbname ( \
		$keyname	integer 	primary key default 0, \
		macgrpname	char(64) 	not null unique default '', \
		macgrpdesc 	char(128) 	not null default '', \
		ranges 		text 	 	not null default '{}', \
		ext		text		\
	)"
