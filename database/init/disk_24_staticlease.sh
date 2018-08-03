#!/bin/sh
. ./init_template_lib.sh
tbname=staticlease
keyname=leaseid

#drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		$keyname	integer 	primary key, \
		host		char(64) 	default '', \
		mac			char(32)	not null unique, \
		ip 			char(16) 	not null unique, \
		leasetime	char(16)	not null default '', \
		leasedesc	char(64) 	not null default '', \
		enable 		integer 	not null default 1 \
	)"
drop_mysql_disk_table $tbname
create_mysql_disk_table "create table $tbname ( \
		$keyname	integer 	primary key, \
		host		char(64) 	default '', \
		mac			char(32)	not null unique, \
		ip 			char(16) 	not null unique, \
		leasetime	char(16)	not null default '', \
		leasedesc	char(64) 	not null default '', \
		enable 		integer 	not null default 1 \
	)"
