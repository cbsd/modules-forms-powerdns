# Linux required -i'', not "-i ''" for inplace
os=$( uname -s )
case "${os}" in
	Linux)
		# Linux require -i'', not -i ' '
		sed_delimer=
		;;
	FreeBSD)
		sed_delimer=" "
		;;
esac

generate_manifest()
{
cat <<EOF
  class { "profiles::services::powerdns": }
EOF
}

generate_hieradata()
{
	local my_common_yaml="${my_module_dir}/common.yaml"
	local _val _tpl
	local zones_part_header="${my_module_dir}/zones_part_header.yaml"
	local zones_part_body="${my_module_dir}/zones_part_body.yaml"

	if [ ! -r ${zones_part_header} ]; then
		echo "no such ${zones_part_header}"
		exit 0
	fi

	if [ ! -r ${zones_part_body} ]; then
		echo "no such ${zones_part_body}"
		exit 0
	fi

	local form_add_zones=0

	if [ -f "${my_common_yaml}" ]; then
		local tmp_common_yaml=$( mktemp )
		/bin/cp ${my_common_yaml} ${tmp_common_yaml}
		for i in ${param}; do
			case "${i}" in
				# start with zones  custom
				zones_name[1-9]*)
					form_add_zones=$(( form_add_zones + 1 ))
					continue;
					;;
				-*)
					# delimier params
					continue
					;;
				Expand)
					# delimier params
					continue
					;;
			esac

			eval _val=\${${i}}
			_tpl="#${i}#"
			# Note that on Linux systems, a space after -i might cause an error
			sed -i${sed_delimer}'' -Ees:"${_tpl}":"${_val}":g ${tmp_common_yaml}
		done
	else
		for i in ${param}; do
			eval _val=\${${i}}
			cat <<EOF
 $i: "${_val}"
EOF
		done
	fi

	# custom zones rules
	if [ ${form_add_zones} -ne 0 ]; then
		cat ${zones_part_header} >> ${tmp_common_yaml}
		tmpfile=$( mktemp )

		zones_name_new=0

		for i in ${param}; do
			case "${i}" in
				zones_name[1-9]*)
					_tpl="#zones_name#"
					eval _val="\${${i}}"
					[ -z "${_val}" ] && continue
					zones_name_new=$(( zones_name_new + 1 ))
					;;
				zones_manage_records[1-9]*)
					_tpl="#zones_manage_records#"
					eval _val="\${${i}}"
					[ -z "${_val}" ] && continue
					zones_name_new=100
					;;
				*)
					continue
					;;
			esac

			if [ ${zones_name_new} -eq 1 ]; then
				cp -a ${zones_part_body} ${tmpfile}
				zones_name_new=$(( zones_name_new + 1 ))
			fi

			rule_name="XXX"         # concat from all field
			sed -i${sed_delimer}'' -Ees@"${_tpl}"@"${_val}"@g ${tmpfile}

			if [ ${zones_name_new} -eq 100 ]; then
				cat ${tmpfile} >> ${tmp_common_yaml}
				zones_name_new=0
			fi
		done
		rm -f ${tmpfile}
	fi

	cat ${tmp_common_yaml}
}
