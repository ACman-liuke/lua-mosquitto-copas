#!/bin/sh
. ./init_template_lib.sh
tbname=report_ap

# drop_mysql_memo_table $tbname
create_mysql_memo_table "create table if not exists $tbname ( \
		devid 		char(24)	not null default '', \
		active		integer		not null default 0, \
		primary key(devid) \
	)"