#!/bin/sh
. ./init_template_lib.sh
tbname=nwlan

# drop_mysql_memo_table $tbname
create_mysql_memo_table "create table if not exists $tbname ( \
		devid 		char(24)	not null default '', \
		band		char(2)		not null default '', \
		bssid		char(18)	not null default '', \
		ssid		char(16)	not null default '', \
		chanid		integer		not null default 0, \
		rssi		integer		not null default 0, \
		valid		integer		not null default 0, \
		active		integer		not null default 0, \
		ext			text		, \
		primary key (devid, band, bssid)
	)"

# 如果key已经存在，更新；否则插入。定时检查active，太久不更新的删除。active使用uptime
# valid:更新时，先把(devid,band)对应的所有记录改为0（失效），再更新有效的记录，并把valid设置为1，以保证不会频繁增删记录。定时根据active把太久没更新的记录删除