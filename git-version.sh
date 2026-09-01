#!/bin/sh

if test x"$REV" = x"systemd"; then
    SYSTEMD="INCLUDE"
    OPENRC="IGNORE"
    SYSV="IGNORE"
elif test x"$REV" = x"openrc"; then
    SYSTEMD="IGNORE"
    OPENRC="INCLUDE"
    SYSV="IGNORE"
elif test x"$REV" = x"sysv"; then
    SYSTEMD="IGNORE"
    OPENRC="IGNORE"
    SYSV="INCLUDE"
else
    echo You must provide either \"systemd\", \"openrc\", or \"sysv\" as an
    echo argument for \"REV\"
    exit 1
fi

if test x"$STAB" = x"development"; then
    DEVELOPMENT="INCLUDE"
    RELEASE="IGNORE"
elif test x"$STAB" = x"release"; then
    DEVELOPMENT="IGNORE"
    RELEASE="INCLUDE"
else
    echo You must provide either \"development\" or \"release\" as argument for
    echo \"STAB\"
    exit 1
fi

if test x"$WORKFLOW" = x"y"; then
    GHP="INCLUDE"
else
    GHP="IGNORE"
fi

echo "<!ENTITY % systemd     \"$SYSTEMD\">"     >  conditional.ent
echo "<!ENTITY % openrc      \"$OPENRC\">"      >> conditional.ent
echo "<!ENTITY % sysv        \"$SYSV\">"        >> conditional.ent
echo "<!ENTITY % development \"$DEVELOPMENT\">" >> conditional.ent
echo "<!ENTITY % release     \"$RELEASE\">"     >> conditional.ent
echo "<!ENTITY % ghp         \"$GHP\">"         >> conditional.ent

if ! git status > /dev/null; then
    # Either it's not a git repository, or git is unavailable.
    # Just workaround.
    echo "<!ENTITY year              \"????\">"            >> conditional.ent
    echo "<!ENTITY version           \"unknown\">"         >  version.ent
    echo "<!ENTITY releasedate       \"unknown\">"         >> conditional.ent
    echo "<!ENTITY pubdate           \"unknown\">"         >> conditional.ent
    exit 0
fi

export LC_ALL=en_US.utf8
export TZ=America/Chicago

commit_date=$(git show -s --format=format:"%cd" --date=local)
short_date=$(date --date "$commit_date" "+%Y-%m-%d")

year=$(date --date "$commit_date" "+%Y")
month=$(date --date "$commit_date" "+%B")
day_digit=$(date --date "$commit_date" "+%d")
day=$(echo $day_digit | sed 's/^0//')

case $day in
    "1" | "21" | "31" ) suffix="st";;
    "2" | "22" ) suffix="nd";;
    "3" | "23" ) suffix="rd";;
    * ) suffix="th";;
esac

full_date="$month $day$suffix, $year"

sha="$(git describe --abbrev=1 --always --exclude '*')"
version=$(echo -n "#" && echo -n "$sha")

if [ "$(git diff HEAD | wc -l)" != "0" ]; then
    version="$version"
fi

echo "<!ENTITY year              \"$year\">"               >> conditional.ent
echo "<!ENTITY version           \"$version\">"            >  version.ent
echo "<!ENTITY releasedate       \"$full_date\">"          >> conditional.ent
echo "<!ENTITY pubdate           \"$short_date\">"         >> conditional.ent
