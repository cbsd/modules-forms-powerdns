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
[ -f "${FORM_PATH}/${HELPER}.sqlite" ] && ${RM_CMD} -f "${FORM_PATH}/${HELPER}.sqlite"

/usr/local/bin/cbsd ${miscdir}/updatesql ${FORM_PATH}/${HELPER}.sqlite ${distsharedir}/forms.schema forms
/usr/local/bin/cbsd ${miscdir}/updatesql ${FORM_PATH}/${HELPER}.sqlite ${distsharedir}/forms.schema additional_cfg
/usr/local/bin/cbsd ${miscdir}/updatesql ${FORM_PATH}/${HELPER}.sqlite ${distsharedir}/forms_system.schema system

${SQLITE3_CMD} ${FORM_PATH}/${HELPER}.sqlite << EOF
BEGIN TRANSACTION;
INSERT INTO forms ( mytable,group_id,order_id,param,desc,def,cur,new,mandatory,attr,type,link,groupname ) VALUES ( 'forms', 1,1,'-Globals','Globals','Globals','PP','',1, 'maxlen=60', 'delimer', '', '' );
INSERT INTO forms ( mytable,group_id,order_id,param,desc,def,cur,new,mandatory,attr,type,link,groupname ) VALUES ( 'forms', 1,2,'db_root_password','Root (superuser) DB password','eikeuj4eipheeTah4nee','eikeuj4eipheeTah4nee','',1, 'maxlen=60', 'inputbox', '', '' );
INSERT INTO forms ( mytable,group_id,order_id,param,desc,def,cur,new,mandatory,attr,type,link,groupname ) VALUES ( 'forms', 1,3,'db_powerdns_password','PowerDNS user DB password','aaZae7Quas9koo6roov2','aaZae7Quas9koo6roov2','',1, 'maxlen=60', 'inputbox', '', '' );
INSERT INTO forms ( mytable,group_id,order_id,param,desc,def,cur,new,mandatory,attr,type,link,groupname ) VALUES ( 'forms', 1,4,'api','Enable PowerDNS API (e.g. required for UI)?','2','2','',2, 'maxlen=128', 'radio', 'api_noyes', '' );
INSERT INTO forms ( mytable,group_id,order_id,param,desc,def,cur,new,mandatory,attr,type,link,groupname ) VALUES ( 'forms', 1,5,'api_key','API token when API enabled','teli2aXoj9eu6ieghein','teli2aXoj9eu6ieghein','',1, 'maxlen=128', 'inputbox', '', '' );
INSERT INTO forms ( mytable,group_id,order_id,param,desc,def,cur,new,mandatory,attr,type,link,groupname ) VALUES ( 'forms', 1,6,'ui','Enable WEB/UI via PowerDNSAdmin?','2','2','',2, 'maxlen=128', 'radio', 'ui_noyes', '' );
INSERT INTO forms ( mytable,group_id,order_id,param,desc,def,cur,new,mandatory,attr,type,link,groupname ) VALUES ( 'forms', 1,500,'-Zones','Zones','Zones','-','',1, 'maxlen=60', 'delimer', '', 'zonesgroup' );
INSERT INTO forms ( mytable,group_id,order_id,param,desc,def,cur,new,mandatory,attr,type,link,groupname ) VALUES ( 'forms', 1,501,'zones','Zones','501','','',0, 'maxlen=60', 'group_add', '', 'zonesgroup' );
COMMIT;
EOF

# api_noyes
/usr/local/bin/cbsd ${miscdir}/updatesql ${FORM_PATH}/${HELPER}.sqlite ${distsharedir}/forms_yesno.schema api_noyes

# Put boolean for api_noyes
${SQLITE3_CMD} ${FORM_PATH}/${HELPER}.sqlite << EOF
BEGIN TRANSACTION;
INSERT INTO api_noyes ( text, order_id ) VALUES ( 'no', 1 );
INSERT INTO api_noyes ( text, order_id ) VALUES ( 'yes', 0 );
COMMIT;
EOF

# ui_noyes
/usr/local/bin/cbsd ${miscdir}/updatesql ${FORM_PATH}/${HELPER}.sqlite ${distsharedir}/forms_yesno.schema ui_noyes

# Put boolean for api_noyes
${SQLITE3_CMD} ${FORM_PATH}/${HELPER}.sqlite << EOF
BEGIN TRANSACTION;
INSERT INTO ui_noyes ( text, order_id ) VALUES ( 'no', 1 );
INSERT INTO ui_noyes ( text, order_id ) VALUES ( 'yes', 0 );
COMMIT;
EOF

# system
${SQLITE3_CMD} ${FORM_PATH}/${HELPER}.sqlite << EOF
BEGIN TRANSACTION;
INSERT INTO system ( helpername, version, packages, have_restart ) VALUES ( 'powerdns', '201607', 'dns/powerdns', 'pdns' );
COMMIT;
EOF

# long description
${SQLITE3_CMD} ${FORM_PATH}/${HELPER}.sqlite << EOF
BEGIN TRANSACTION;
UPDATE system SET longdesc='\\
PowerDNS Server + (optional) PowerDNSAdmin UI \\
\\
The PowerDNS Authoritative Server is a versatile nameserver which supports a \\
large number of backends. These backends can either be plain zone files or be \\
more dynamic in nature. \\
\\
PowerDNS has the concepts of 'backends'. A backend is a datastore that the \\
server will consult that contains DNS records (and some metadata). The backends \\
range from database backends (MySQL, PostgreSQL) and BIND zone files to \\
co-processes and JSON APIs. \\
 \\
';
COMMIT;
EOF
