#!/bin/sh
# ex: set tabstop=4 expandtab smarttab softtabstop=4 shiftwidth=4:

# $Source: /home/xubuntu/berlios_backup/github/tmp-cvs/pdnso/Repository/PublicDNSorg/daemons/pdsysd.sh,v $
# $Revision: 1.1 $
# $Date: 2005/11/23 03:42:57 $
# $Author: unrtst $


# shell script to start pdsysd.pl

export PERL5LIB=/usr/local/PublicDNSorg/lib

start() {
    if [ -x /usr/local/bin/pdsysd.pl ]; then
        /usr/local/bin/pdsysd.pl &
        echo -n ' pdsysd'
    fi
    return 0
}
stop() {
    kill `head -1 /var/run/pdsysd.pl.pid`
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

