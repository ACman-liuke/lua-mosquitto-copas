#!/bin/sh

. ./init_template_lib.sh
tbname=smartdevice
keyname=deviceid

#drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		$keyname		char(32) primary key	not null default '', \
		name			char(64) 				not null default '', \
		apikey			char(64)				not null default '', \
		mac 			char(18) 				not null default '', \
		ip 				char(16) 				not null default '', \
		register 		char(18) 				not null default '', \
		bind 			char(16) 				not null default '', \
		state			char(8) 				not null default '', \
		online_time 	datetime				not null default '1970-01-01 08:00:00', \
		offline_time	datetime				not null default '1970-01-01 08:00:00', \
		active 			integer 				not null default 0, \
		code 			char(64) 				not null default '', \
		blacklist		char(8)					not null default 'false',\
		ext 			text					\
	)"

drop_mysql_disk_table $tbname
create_mysql_disk_table "create table $tbname ( \
		$keyname		char(32) primary key	not null default '', \
		name			char(64) 				not null default '', \
		apikey			char(64)				not null default '', \
		mac 			char(18) 				not null default '', \
		ip 				char(16) 				not null default '', \
		register 		char(18) 				not null default '', \
		bind 			char(16) 				not null default '', \
		state			char(8) 				not null default '', \
		online_time 	datetime				not null default '1970-01-01 08:00:00', \
		offline_time	datetime				not null default '1970-01-01 08:00:00', \
		active 			integer 				not null default 0, \
		code 			char(64) 				not null default '', \
		blacklist		char(8)					not null default 'false',\
		ext 			text					\
	)"

