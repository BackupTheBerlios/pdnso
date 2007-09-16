#!/bin/sh
# ex: set tabstop=4 expandtab smarttab softtabstop=4 shiftwidth=4:

# $Source: /home/xubuntu/berlios_backup/github/tmp-cvs/pdnso/Repository/PublicDNSorg/daemons/pdsysd.sh,v $
# $Revision: 1.3 $
# $Date: 2007/09/16 22:55:25 $
# $Author: unrtst $


# shell script to start pdsysd.pl

export PERL5LIB=/usr/local/PublicDNSorg/lib

start() {
    if [ -x /usr/local/PublicDNSorg/daemons/pdsysd.pl ]; then
        /usr/local/PublicDNSorg/daemons/pdsysd.pl &
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

