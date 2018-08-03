#!/bin/sh
. ./init_template_lib.sh
tbname=apstate

# drop_mysql_memo_table $tbname
create_mysql_memo_table "create table if not exists $tbname ( \
		devid 		char(24)	not null default '', \
		devdesc		 char(64)	not null default '', \
		ip 			char(15)	not null default '', \
		uptime 		char(16)	not null default '', \
		firmware	char(24)	not null default '', \
		state 		char(8)		not null default '', \
		users		integer		not null default 0, \
		radios 		char(16)		not null default '', \
		naps 		integer		not null default 0, \
		login 		datetime	not null default '0000-00-00 00:00:00', \
		active 		integer		not null default 0, \
		ext			text		, \
		primary key(devid) \
	)"

# status启动或者监听到device表更新时，同步对应内容到此表。查询时不与device连表。
# 同步 devid, devdesc, radios
# 更新表sta时，同步更新字段users
# 更新表nap时，同步更新字段naps
# ext:扩展字段，暂时不用
