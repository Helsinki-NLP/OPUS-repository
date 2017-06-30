#!/bin/bash

test "$DBNAME" != "" || { echo "source configuration first" ; exit 1; }
test "$DBUSER" != "" || { echo "source configuration first" ; exit 1; }
test "$DBPASS" != "" || { echo "source configuration first" ; exit 1; }
test "$DBHOST" != "" || { echo "source configuration first" ; exit 1; }
test "$DBPORT" != "" || { echo "source configuration first" ; exit 1; }

DBMTEST="mysql --password=$DBPASS -u $DBUSER -h $DBHOST -P $DBPORT"


function user_exists() {
    local USR=$1

    echo 'select User from mysql.user;' | $DBMTEST | grep -q "^$USR$"
}


function database_exists() {
    local DB=$1

    echo 'show databases' | $DBMTEST | grep -q "^$DB$"
}

# check if the DBUSER and th DB exist already

if user_exists $DBUSER; then 
    if database_exists $DBNAME; then 
	exit 0; 
    fi
fi

# otherwise: ask for root password and create databases and tables

MYSQLADMINUSER=$(whiptail --inputbox "MySQL admin user" 8 30   2>&1 >/dev/tty)
MYSQLADMINPASS=$(whiptail --passwordbox "MySQL admin password" 8 30  2>&1 >/dev/tty)
DBM="mysql --password=$MYSQLADMINPASS -u $MYSQLADMINUSER -h $DBHOST -P $DBPORT"


### Dropped this stuff. It's a good idea, but unreliable, as mysql seem to have some
### sort of bug. On some installations, --defaults-file is accepted, on some
### its's silently ignored.
# ### the most secure way of handing mysql a password noninteract5Aively
# MYSQLTMPAUTH=$(tempfile /tmp/mysqlXXXXXXXXXX)
# DBM="mysql --defaults-file=$MYSQLTMPAUTH -u $MYSQLADMINUSER -h $DBHOST -P $DBPORT"
# touch $MYSQLTMPAUTH && chmod 600 $MYSQLTMPAUTH
# cat <<EOF > $MYSQLTMPAUTH
# [client]
# password=$MYSQLADMINPASS
# EOF



###########################################################


function create_mysql_user() {
    local USR="$1" # username
    local PAS="$2" # password
    local TAB="$3" # table on which the new user will have all privs

    echo "**** creating mysql user $DB" >&2

    cat <<EOF | $DBM
FLUSH PRIVILEGES;
CREATE USER '$USR'@'localhost' IDENTIFIED BY '$PAS';
GRANT ALL PRIVILEGES ON $TAB.* TO '$USR'@'%';
FLUSH PRIVILEGES;
EOF
}



function create_db() {
    local DB=$1

    echo "**** creating database $DB" >&2

    cat <<EOF | $DBM
CREATE DATABASE $DB CHARACTER SET = utf8;
EOF
}


###########################################################


user_exists $DBUSER     || create_mysql_user "$DBUSER" "$DBPASS" "$DBNAME"
database_exists $DBNAME || create_db $DBNAME
rm -f $MYSQLTMPAUTH
