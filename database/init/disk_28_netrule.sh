#!/bin/sh
. ./init_template_lib.sh
tbname=netrule
keyname=ruleid

#drop_sqlite3_disk_table $tbname
create_sqlite3_disk_table $tbname $keyname "create table if not exists $tbname ( \
        $keyname    integer     primary key, \
        mac         char(24)    not null unique default '', \
        devicename  char(64)    not null default '', \
        active      char(24)    not null default '',\
        enable      char(8)     not null default '',\
        desc        char(128)   not null default '',\
        time_list   text        not null default '', \
        ext         text    \
    )"

drop_mysql_disk_table $tbname
create_mysql_disk_table "create table $tbname ( \
        $keyname    integer     primary key, \
        mac         char(24)    not null unique default '', \
        devicename  char(64)    not null default '', \
        active      char(24)    not null default '',\
        enable      char(8)     not null default '',\
        desc        char(128)   not null default '',\
        time_list   text        not null default '', \
        ext         text    \
    )"
