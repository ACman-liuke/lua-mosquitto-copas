#!/bin/sh
. ./init_template_lib.sh
tbname=radiostate

# drop_mysql_memo_table $tbname
create_mysql_memo_table "create table if not exists $tbname ( \
		devid 			char(24)	not null default '', \
		band			char(2)		not null default '', \
		proto 			char(6)		not null default '', \
		chanid 			integer		not null default 0, \
		bandwidth  		char(6)		not null default '', \
		pow 			integer		not null default 0, \
		maxpow  		integer		not null default 0, \
		chanuse 		integer		not null default 0, \
		noise 			integer		not null default 0, \
		users  			integer 	not null default 0, \
		wlan_run_cnt 	integer 	not null default 0, \
		nwlan_cnt 		integer 	not null default 0, \
		active			integer		not null default 0, \
		ext				text		, \
		primary key(devid, band) \
	)"

# 更新表sta时，同步更新字段users
# 更新表wlan_run时，同步更新字段wlan_run_cnt
# 更新表nwlan时，同步更新字段nwlan_cnt
# ext:扩展字段，暂时不用
