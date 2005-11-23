#!/bin/sh
# ex: set tabstop=4 expandtab smarttab softtabstop=4 shiftwidth=4:

# $Source: /home/xubuntu/berlios_backup/github/tmp-cvs/pdnso/Repository/PublicDNSorg/daemons/pdsysd_slaves.sh,v $
# $Revision: 1.1 $
# $Date: 2005/11/23 03:42:57 $
# $Author: unrtst $

export PERL5LIB=/usr/local/PublicDNSorg/lib

# shell script to start pdsysd_slave.pl
start() {
    if [ -x /usr/local/pdsys/pdsysd_slaves.pl ]; then
        /usr/local/pdsys/pdsysd_slaves.pl &
        echo -n ' pdsysd'
    fi
    return 0
}

stop() {
    kill `head -1 /var/run/pdsysd_slaves.pl.pid`
    echo -n ' pdsysd'
    return 0
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    *)
        echo ""
        echo "Usage: `basename $0` { start | stop | restart }"
        echo ""
        exit 64
        ;;
esac

