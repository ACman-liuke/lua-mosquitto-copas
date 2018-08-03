#!/bin/sh
. ./init_template_lib.sh
tbname=usagerecord
keyname=recordid

drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		$keyname 	integer 	primary key autoincrement, \
		mac 		char(24)	not null unique default '', \
        ukey        char(32)    not null default '', \
		ruleid		integer		not null default 0, \
        rulename    char(64)    not null default '',\
		netusage	integer		not null default 0,\
		ext 		text	\
	)"

drop_mysql_disk_table $tbname
create_mysql_disk_table "create table $tbname ( \
        $keyname    integer     primary key autoincrement, \
        mac         char(24)    not null unique default '', \
        ukey        char(32)    not null default '', \
        ruleid      integer     not null default 0, \
        rulename    char(64)    not null default '',\
        netusage    integer     not null default 0,\
        ext         text    \
	)"

# 当用户被指定临时策略时，临时保存用户之前使用的策略，临时策略失效后，删除该策略