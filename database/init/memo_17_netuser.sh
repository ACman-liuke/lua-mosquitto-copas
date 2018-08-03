#!/bin/sh
. ./init_template_lib.sh
tbname=netuser
keyname=userid

# drop_mysql_memo_table $tbname
create_mysql_memo_table "create table if not exists $tbname ( \
        $keyname        integer         primary key autoincrement,\
        mac             char(24)        not null unique default '', \
        ip              char(24)        not null default '', \
        ukey            char(32)        not null default '', \
        hostname        char(64)        not null default '', \
        ruleid          char(8)         not null default '', \
        blacklist       char(8)         not null default 'false',\
        ruleset         char(8)         not null default 'no',\
        active          integer         not null default 0,\
        login           integer         not null default 0,\
        nettype         char(8)         not null default '',\
        status          char(8)         not null default 'offline',\
        ext             text    \
)"