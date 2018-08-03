#!/bin/sh
. ./init_template_lib.sh
tbname=wifirule
keyname=ruleid

#drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
        $keyname    integer     primary key default 0, \
        weeklist    char(64)    not null default '{}', \
        starttime   char(24)    not null default '',\
        stoptime    char(24)    not null default '',\
        enable      char(8)     not null default ''\
    )"

drop_mysql_disk_table $tbname
create_mysql_disk_table "create table $tbname ( \
        $keyname    integer     primary key default 0,\
        weeklist    char(64)    not null default '{}',\
        starttime   char(24)    not null default '',\
        stoptime    char(24)    not null default '',\
        enable      char(8)     not null default ''\
    )"