#!/bin/sh
pgm="${0##*/}"          # Program basename
progdir="${0%/*}"       # Program directory
: ${REALPATH_CMD=$( which realpath )}
: ${SQLITE3_CMD=$( which sqlite3 )}
: ${RM_CMD=$( which rm )}
: ${MKDIR_CMD=$( which mkdir )}
: ${FORM_PATH="/opt/forms"}
: ${distdir="/usr/local/cbsd"}

MY_PATH="$( ${REALPATH_CMD} ${progdir} )"
HELPER="powerdns"

# MAIN
if [ -z "${workdir}" ]; then
	[ -z "${cbsd_workdir}" ] && . /etc/rc.conf
	[ -z "${cbsd_workdir}" ] && exit 0
	workdir="${cbsd_workdir}"
fi

set -e
. ${distdir}/cbsd.conf
. ${subrdir}/tools.subr
. ${subr}
set +e

FORM_PATH="${workdir}/formfile"

[ ! -d "${FORM_PATH}" ] && err 1 "No such ${FORM_PATH}"

###
groupname="dbgroup"

err() {
	exitval=$1
	shift
	echo "$*"
	exit $exitval
}

add()
{

	if [ -r "${formfile}" ]; then
		/usr/local/bin/cbsd ${miscdir}/updatesql ${formfile} ${distsharedir}/forms_yesno.schema manage_zones_truefalse${index}

		${SQLITE3_CMD} ${formfile} << EOF
BEGIN TRANSACTION;
INSERT INTO manage_zones_truefalse ( text, order_id ) VALUES ( 'true', 1 );
INSERT INTO manage_zones_truefalse ( text, order_id ) VALUES ( 'false', 0 );
COMMIT;
EOF


		${SQLITE3_CMD} ${formfile} <<EOF
BEGIN TRANSACTION;
INSERT INTO forms ( mytable,group_id,order_id,param,desc,def,cur,new,mandatory,attr,xattr,type,link,groupname ) VALUES ( 'forms', ${index},${order_id},'zones_name${index}','zone name, e.g: 'example.org'','example.org','','',1, 'maxlen=60', 'dynamic', 'inputbox', '', '${groupname}' );
INSERT INTO forms ( mytable,group_id,order_id,param,desc,def,cur,new,mandatory,attr,xattr,type,link,groupname ) VALUES ( 'forms', ${index},${order_id},'zones_manage_records${index}','create initial entries?','manage_records${index}','manage_records${index}','true',1, 'maxlen=60', 'dynamic', 'radio', 'manage_zones_truefalse', '${groupname}' );
COMMIT;
EOF
	else
		/bin/cat <<EOF
BEGIN TRANSACTION;
INSERT INTO forms ( mytable,group_id,order_id,param,desc,def,cur,new,mandatory,attr,type,link,groupname ) VALUES ( 'forms', ${index},${order_id},'hba_rule${index}','hba_rule part ${index}','','','',1, 'maxlen=60', 'inputbox', '', '${groupname}' );
COMMIT;
EOF
	fi
}


del()
{

	if [ -r "${formfile}" ]; then
		${SQLITE3_CMD} ${formfile} <<EOF
BEGIN TRANSACTION;
DELETE FROM forms WHERE group_id = '${index}' AND groupname = '${groupname}';
COMMIT;
EOF
	else
		/bin/cat <<EOF
BEGIN TRANSACTION;
DELETE FROM forms WHERE group_id = '${index}' AND groupname = '${groupname}';
COMMIT;
EOF
	fi
}

usage()
{
	echo "$0 -a add/remove -i index"
}


get_index()
{
	local new_index

	[ ! -r "${formfile}" ] && err 1 "formfile not readable: ${formfile}"
	new_index=$( ${SQLITE3_CMD} ${formfile} "SELECT group_id FROM forms WHERE groupname = '${groupname}' ORDER BY group_id DESC LIMIT 1" )

	case "${action}" in
		add|create)
			index=$(( new_index + 1 ))
			;;
		del*|remove)
			index=$new_index
			;;
	esac

	[ "${index}" = "0" ] && index=1	# protect ADD custom button

}

while getopts "a:i:f:o:" opt; do
	case "$opt" in
		a) action="${OPTARG}" ;;
		i) index="${OPTARG}" ;;
		f) formfile="${OPTARG}" ;;
		o) order_id="${OPTARG}" ;;
	esac
	shift $(($OPTIND - 1))
done

[ -z "${action}" ] && usage
[ -z "${index}" -a -n "${formfile}" ] && get_index
[ -z "${index}" -a -z "${formfile}" ] && index=1
[ -z "${order_id}" -a -z "${formfile}" ] && order_id=1

#echo "Index: $index, Action: $action, Groupname: $groupname"

case "${action}" in
	add|create)
		add
		;;
	del*|remove)
		del
		;;
	*)
		echo "Unknown action: must be 'add' or 'del'"
		;;
esac
