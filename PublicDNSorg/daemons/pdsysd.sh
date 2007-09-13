#!/bin/sh
# ex: set tabstop=4 expandtab smarttab softtabstop=4 shiftwidth=4:

# $Source: /home/xubuntu/berlios_backup/github/tmp-cvs/pdnso/Repository/PublicDNSorg/daemons/pdsysd.sh,v $
# $Revision: 1.2 $
# $Date: 2007/09/13 05:20:30 $
# $Author: unrtst $


# shell script to start pdsysd.pl

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

