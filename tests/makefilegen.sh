#!/bin/sh

cd "$(dirname "$0")" || exit 111

LANG=C
export LANG

programs='_tinysshd-printkex _tinysshd-test-global-request _tinysshd-test-hello1 _tinysshd-test-hello2 _tinysshd-test-ignore _tinysshd-test-kex1 _tinysshd-test-kex2 _tinysshd-test-packet _tinysshd-test-sequence _tinysshd-unauthenticated tinysshd'
links='tinysshd-makekey tinysshnoneauthd'
autoheaders=''
objects=''
allobjects=''
testout=''

for file in *.c; do
    object=${file%.c}.o
    allobjects="$allobjects $object"
    case "$file" in
        has*.c)
            autoheaders="$autoheaders ${file%.c}.h"
            ;;
        randombytes.c)
            ;;
        _tinysshd-printkex.c | _tinysshd-test-global-request.c | \
        _tinysshd-test-hello1.c | _tinysshd-test-hello2.c | \
        _tinysshd-test-ignore.c | _tinysshd-test-kex1.c | \
        _tinysshd-test-kex2.c | _tinysshd-test-packet.c | \
        _tinysshd-test-sequence.c | \
        _tinysshd-unauthenticated.c | tinysshd.c)
            ;;
        *)
            objects="$objects $object"
            ;;
    esac
done

for file in test-*.sh; do
    testout="$testout ${file%.sh}.out"
done

(
    echo 'CC?=cc'
    echo 'CFLAGS+=-W -Wall -Os -fPIC -fwrapv -I../cryptoint'
    echo 'LDFLAGS?='
    echo 'CPPFLAGS?='
    echo
    echo "PROGRAMS=$programs"
    echo "LINKS=$links"
    echo "OBJECTS=$objects"
    echo "ALLOBJECTS=$allobjects"
    echo "AUTOHEADERS=$autoheaders"
    echo "TESTOUT=$testout"
    echo
    echo 'all: $(AUTOHEADERS) $(PROGRAMS) $(LINKS)'
    echo

    touch $autoheaders
    for object in $allobjects; do
        source=${object%.o}.c
        ${CC:-cc} -MM -isystem /usr/local/include -I../cryptoint "$source"
        echo "\t\$(CC) \$(CFLAGS) \$(CPPFLAGS) -c $source"
        echo
    done
    rm -f $autoheaders

    for program in $programs; do
        echo "$program: $program.o \$(OBJECTS) randombytes.o libs"
        printf '\t$(CC) $(CFLAGS) $(CPPFLAGS) -o %s %s.o \\\n' \
            "$program" "$program"
        printf '\t$(OBJECTS) $(LDFLAGS) `cat libs` randombytes.o\n'
        echo
    done

    for header in $autoheaders; do
        source=${header%.h}.c
        logfile=${header%.h}.log
        echo "$header: tryfeature.sh $source libs"
        printf '\tenv CC="$(CC)" CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS) `cat libs`" \\\n'
        echo "\t./tryfeature.sh $source >$header 2>$logfile"
        echo "\tcat $header"
        echo
    done

    for output in $testout; do
        script=${output%.out}.sh
        expected=${output%.out}.exp
        echo "$output: \$(PROGRAMS) \$(LINKS) $script $expected"
        echo "\tsh $script >$output"
        echo "\tcmp $expected $output"
        echo
    done

    echo 'test: $(PROGRAMS) $(LINKS)'
    echo '\tsh test.sh'
    echo
    echo 'libs: trylibs.sh'
    echo '\tenv CC="$(CC)" ./trylibs.sh -lsocket -lnsl -lutil -lrandombytes -l25519 -l1305 -lntruprime >libs 2>libs.log'
    echo '\tcat libs'
    echo
    echo 'tinysshd-makekey: tinysshd'
    echo '\trm -f tinysshd-makekey'
    echo '\tln -s tinysshd tinysshd-makekey'
    echo
    echo 'tinysshnoneauthd: tinysshd'
    echo '\trm -f tinysshnoneauthd'
    echo '\tln -s tinysshd tinysshnoneauthd'
    echo
    echo 'clean:'
    echo '\trm -f *.log *.o *.out libs $(PROGRAMS) $(LINKS) $(AUTOHEADERS)'
    echo '\trm -rf keydir keydir-ignore'
) >Makefile
