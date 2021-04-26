#!/bin/dash

unlink /tmp/dpkg-status 2> /dev/null
touch /tmp/dpkg-status 2> /dev/null

IFS="	"

PKGLIST=
AVAILABLE=./packages-avail
ADD_STATUS=false

while [ $# -gt 0 ]; do
	case $1 in
		"--avail")
			shift 1
			AVAILABLE=$1
			shift 1 ;;

		"--pkglist")
			shift 1
			PKGLIST=$1
			shift 1 ;;

		"--status")
			ADD_STATUS=true
			shift 1 ;;

		*)
			echo "Usage: dpkg-status.sh --debian X --pkglist X [ --status ]"
			exit 1
			shift 1 ;;
	esac
done

echo ""
echo "You selected ..."
echo "    STATUS:  $ADD_STATUS"
echo "    PKGLIST: $PKGLIST"
echo "    AVAIL:   $AVAILABLE"
echo "    OUTPUT:  /tmp/dpkg-status"
echo ""
echo -n "Do you want to proceed (y/n) ? "
read answer

if [ "$answer" != "y" ]; then
	exit 1
fi

if [ ! -f "$AVAILABLE" -o ! -f "$PKGLIST" ]; then
	echo "You must provide valid status and package list files !"
	exit 1
fi

add_status_line() {

	pkg=$(echo "$1" | /bin/sed -e 's/\./\\./g')
	pkg=$(echo "$pkg" | /bin/sed -e 's/\+/./g')
	pkg=$(echo "$pkg" | /bin/sed -e 's/\-/./g')

	status=$(grep -E "/$pkg"_ $PKGLIST)

	if [ "$status" = "" ]; then
		echo "Status: install ok not-installed" >> /tmp/dpkg-status
	else
		echo "Status: install ok unpacked" >> /tmp/dpkg-status
	fi
}

cat $AVAILABLE | while read line; do

	if [ "$line" = "" ]; then
		echo "" >> /tmp/dpkg-status

	elif [ "`echo $line | egrep -E '^Package:'`" != "" ]; then

		echo "Processing '$line'"
		pkg=$(echo $line | /bin/sed -e 's/Package: //g')
		echo $line >> /tmp/dpkg-status

		if [ "$ADD_STATUS" = true ]; then
			add_status_line $pkg
		fi
	elif [ "`echo $line | egrep -E '^Status:'`" != "" ]; then
		add_status_line $pkg
	else
		echo $line >> /tmp/dpkg-status
	fi
done

grep -v -E "^Filename:" /tmp/dpkg-status 1> /tmp/dpkg-status.1

/bin/mv /tmp/dpkg-status.1 /tmp/dpkg-status

DESKTOP=$(basename $PKGLIST ".lst")

xz -F lzma -c /tmp/dpkg-status 1> install/factory/dpkg-status-$DESKTOP.lzma

exit 0

