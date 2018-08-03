#!/bin/sh
. ./init_template_lib.sh
tbname=blackset
keyname=setid

#drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
        $keyname    integer     primary key autoincrement,\
		mac       	char(24) 	not null unique default '', \
		hostname	char(64)	not null default '',\
		ext 		text	\
	)"
drop_mysql_disk_table $tbname
create_mysql_disk_table "create table $tbname ( \
        $keyname    integer     primary key autoincrement,\
        mac         char(24)    not null unique default '', \
        hostname    char(64)    not null default '',\
        ext         text    \
	)"
