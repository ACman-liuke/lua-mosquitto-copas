#/bin/sh
. ./init_template_lib.sh
tbname=urls
keyname=gid

#drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
		$keyname  integer 	primary key default 0, \
		name	  char(64) 	not null unique, \
		urldesc   char(128) not null default '', \
		enable	  integer 	not null default 1, \
		urllist   text, \
		urltype   text, \
		url_ids   text \
	)"
drop_mysql_disk_table $tbname
create_mysql_disk_table "create table $tbname ( \
		$keyname  integer 	primary key default 0, \
		name	  char(64) 	not null unique, \
		urldesc   char(128) not null default '', \
		enable	  integer 	not null default 1, \
		urllist   text, \
		urltype   text, \
		url_ids   text \
	)"