#!/bin/bash -

PROJECT=libguestfs
FEBOOTSTRAP_PATH=$HOME/d/febootstrap
MAILTO=libguestfs@redhat.com
HOSTNAME="$(hostname -s)"

#----------------------------------------------------------------------
# Helper functions.

failed ()
{
    mail -s "$HOSTNAME $PROJECT FAILED $1 $gitsha" $MAILTO < local-log
}

ok ()
{
    mail -s "$HOSTNAME $PROJECT success $gitsha" $MAILTO < local-log
}

#----------------------------------------------------------------------

set -e
set -x

# Make sure we build and test against latest febootstrap.
PATH=$FEBOOTSTRAP_PATH:$FEBOOTSTRAP_PATH/helper:$PATH

# Remove any old cache directories.
rm -rf /tmp/guestfs.* ||:

rm -f local-log
cat > local-log <<EOF

This is an automatic message generated by the builder on
$HOSTNAME for $PROJECT.  Log files from the build
follow below.

$(uname -a)
$(date)

-----

EOF
exec >> local-log 2>&1

# Pull from the public repo so that we don't need ssh-agent.
git pull --rebase git://git.annexia.org/git/libguestfs.git master
git clean -d -f

# The git version we are building.
gitsha=$(git log|head -1|awk '{print $2}')

# Do the configure step.
./bootstrap ||:
./autogen.sh --enable-gcc-warnings || {
    failed "configure step"
    exit 1
}

# Do the build step.
make || {
    failed "build step"
    exit 1
}

# Tests that are skipped (note that these tests should be fixed).
case "$HOSTNAME" in
    builder-ubuntu)
        # get_e2uuid: /dev/vdc: [no error message]
        # get_e2label: /dev/vda1: [no error message]
        # Diagnosis: either mkjournal is not writing a UUID or blkid is
        # unable to pick it up.
        export SKIP_TEST_GET_E2UUID=1
        export SKIP_TEST_SET_E2UUID=1
        export SKIP_TEST_SET_E2LABEL=1

	# Avoids:
	# device-mapper: ioctl: unable to remove open device temporary-cryptsetup-661
	# device-mapper: remove ioctl failed: Device or resource busy
	# guestfsd: error: Device lukstest is busy.
	# Diagnosis: appears to be a bug in cryptsetup on Ubuntu.
	# https://bugzilla.redhat.com/show_bug.cgi?id=527056
	export SKIP_TEST_LUKS_SH=1
	;;
esac

# Run the tests.
make check || {
    failed "tests"
    exit 1
}

ok