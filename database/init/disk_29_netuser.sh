#!/bin/sh
. ./init_template_lib.sh
tbname=netuser
keyname=userid

# blacklist: 记录用户是否被拉黑 true 表明被拉黑，false 表明未被拉黑
# attention: 记录用户是否被关注 follow 表明被关注
# ruleset : 记录用户是被管理员处理放通,还是系统未开启认证自动放通上网
# login	: 用户上线时间, 单位 s
# status: 表明用户的在线状态，online：在线，offline：离线

#drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		$keyname	integer		primary key autoincrement,\
		mac		 	char(24) 	not null unique default '', \
		ip 			char(24)	not null default '', \
		ukey 		char(32)	not null default '', \
		hostname	char(64)	not null default '', \
		ruleid      char(8)     not null default '', \
		blacklist	char(8)		not null default 'false',\
		ruleset		char(8)		not null default 'no',\
		active		integer		not null default 0,\
		login		integer		not null default 0,\
		nettype 	char(8)		not null default '',\
		status		char(8)		not null default 'offline',\
		ext 		text	\
	)"

drop_mysql_disk_table $tbname
create_mysql_disk_table "create table $tbname ( \
		$keyname	integer		primary key autoincrement,\
		mac		 	char(24) 	not null unique default '', \
		ip 			char(24)	not null default '', \
		ukey 		char(32)	not null default '', \
		hostname	char(64)	not null default '', \
		ruleid      char(8)     not null default '', \
		blacklist	char(8)		not null default 'false',\
		ruleset		char(8)		not null default 'no',\
		active		integer		not null default 0,\
		login		integer		not null default 0,\
		nettype 	char(8)		not null default '',\
		status		char(8)		not null default 'offline',\
		ext 		text	\
	)"