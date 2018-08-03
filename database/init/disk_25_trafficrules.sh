#!/bin/sh 
. ./init_template_lib.sh
tbname=trafficrules
keyname=protoid

#drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		$keyname	integer 		primary key default 0, \
		name		char(32)		not null unique default '', \
		desc  		char(32) 		not null default '', \
		enable		integer 		not null default 1, \
		priority	interger		not null default 0, \
		family		char(8)			not	null default '', \
		target		char(8)			not null default '', \
		proto 		char(8) 		not null default '', \
		src_zid 	integer 		not null default 0, \
		src_ip		char(24)  		not null default '', \
		src_mac		char(32)		not null default '', \
		src_port 	integer 		not null default '', \
		src_dip		char(24)  		not null default '', \
		src_dport	integer 		not null default '', \
		dest_zid	integer 		not null default 0, \
		dest_port 	integer 		not null default '', \
		dest_ip		char(24)  		not null default '', \
		tmgrp_ids	integer 		not null default 255, \
		ext			varchar(256)	, \
		foreign key(src_zid) references zone(zid) on delete restrict on update restrict, \
		foreign key(dest_zid) references zone(zid) on delete restrict on update restrict, \
		foreign key(tmgrp_ids) references timegroup(tmgid) on delete restrict on update restrict \
	)"
drop_mysql_disk_table $tbname	
create_mysql_disk_table "create table $tbname ( \
		$keyname	integer 		primary key default 0, \
		name		char(32)		not null unique default '', \
		desc  		char(32) 		not null default '', \
		enable		integer 		not null default 1, \
		priority	interger		not null default 0, \
		family		char(8)			not	null default '', \
		target		char(8)			not null default '', \
		proto 		char(8) 		not null default '', \
		src_zid 	integer 		not null default 0, \
		src_ip		char(24)  		not null default '', \
		src_mac		char(32)		not null default '', \
		src_port 	integer 		not null default '', \
		src_dip		char(24)  		not null default '', \
		src_dport	integer 		not null default '', \
		dest_zid	integer 		not null default 0, \
		dest_port 	integer 		not null default '', \
		dest_ip		char(24)  		not null default '', \
		tmgrp_ids	integer 		not null default 255, \
		ext			varchar(256)	\
	)"
# ext:扩展字段，暂时不用
#dip与dport暂时未用到，作为保留字段，功能扩展
