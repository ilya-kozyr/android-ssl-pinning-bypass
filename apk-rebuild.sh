#!/bin/bash

set_vars() {
	NC=$'\e[0m'
	CYAN=$'\e[0;36m'
	RED=$'\e[0;31m'
	YELLOW=$'\e[0;33m'
	GREEN=$'\e[0;32m'
	BLACK=$'\e[1m'
	prefix=$(basename "$0")
	filename_suffix='-patched'
}

set_path() {
	tools_catalog="$HOME/etc"
	tools=(
		'bundletool-all-' '1.8.2' 'https://github.com/google/bundletool/releases/download/' 'bundletool'
		'apktool_' '2.6.0' 'https://github.com/iBotPeaches/Apktool/releases/download/v' 'apktool'
		'uber-apk-signer-' '1.2.1' 'https://github.com/patrickfav/uber-apk-signer/releases/download/v' 'uber-apk-signer'
	)
	bundletool_path="$tools_catalog/${tools[0]}${tools[1]}.jar"
	apktool_path="$tools_catalog/${tools[4]}${tools[5]}.jar"
	uber_apk_signer_path="$tools_catalog/${tools[8]}${tools[9]}.jar"
	keystore_catalog="$HOME/.android"
	keystore_path="$keystore_catalog/debug.keystore"
}

check_tools() {
	if [[ ! -d "$tools_catalog" ]]; then mkdir -p "$tools_catalog"; fi
	have_all_tools=true

	for((i=0;i<${#tools[@]};i=i+4)); do
		tool_bin_name="${tools[i]}${tools[i+1]}"
		tool_bin_url="${tools[i+2]}${tools[i+1]}/$tool_bin_name.jar"
		if [[ ! -f "$tools_catalog/$tool_bin_name.jar" ]]; then
			log_err "$tool_bin_name is missing"
			log_warn "Removing previous versions of ${tools[i+3]} from $tools_catalog"
			find "$tools_catalog" -name "${tools[i+3]}*.jar" -delete
			log_info "Downloading $tool_bin_name to $tools_catalog from $tool_bin_url"
			curl -fsSL "$tool_bin_url" --output "$tools_catalog/$tool_bin_name.jar"
			echo
			if [[ ! -f "$tools_catalog/$tool_bin_name.jar" ]]; then
				have_all_tools=false
				log_err "Unable to download $tool_bin_name"
				echo
			fi
		fi
	done

	if [[ $(which xmlstarlet) == "" ]]; then
		log_err "xmlstarlet is missing"
		if [[ $(which brew) == "" ]]; then
			log_err "Unable to install xmlstarlet, Homebrew is missing"
			have_all_tools=false
		else
			log_info "Installing xmlstarlet"
			brew install xmlstarlet
			if [[ $(which xmlstarlet) == "" ]]; then
				have_all_tools=false
				log_err "Unable to install xmlstarlet, install it manually"
			fi
		fi
	fi

	if [[ $arg_ks == '' ]]; then
		if [[ ! -f "$keystore_path" ]]; then
			log_err "keystore is missing"
			if [[ $(which keytool) == "" ]]; then
				if [[ $(which brew) == "" ]]; then
					log_err "Unable to install openjdk, Homebrew is missing"
					have_all_tools=false
				else
					log_err "keytool is missing"
					log_info "Installing openjdk"
					brew install openjdk
					if [[ $(which keytool) == "" ]]; then
						have_all_tools=false
						log_err "Unable to install openjdk, install it manually"
					else
						if [[ ! -d "$keystore_catalog" ]]; then mkdir -p "$keystore_catalog"; fi
						log_info "Generating keystore"
						keytool -genkey -v -keystore "$keystore_path" -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "C=US, O=Android, CN=Android Debug"
					fi
				fi
			fi
		fi
	else
		ks_file_path=$(cd "$(dirname "$arg_ks")" && pwd)
		ks_file_name=$(basename "$arg_ks")
		if [[ ! -f "$ks_file_path/$ks_file_name" ]]; then
			log_err "Keystore file $ks_file_path/$ks_file_name is missing"
			have_all_tools=false
		fi
		if [[ $arg_ks_pass == '' ]]; then
			log_err "Keystore password is missing, specify it with --ks-pass argument"
			have_all_tools=false
		fi
		if [[ $arg_ks_alias == '' ]]; then
			log_err "Keystore alias is missing, specify it with --ks-alias argument"
			have_all_tools=false
		fi
		if [[ $arg_ks_key_pass == '' ]]; then
			log_err "Key password is missing, specify it with --ks-key-pass argument"
			have_all_tools=false
		fi

		ks_test=$(keytool -list -keystore "$ks_file_path/$ks_file_name" -storepass "$arg_ks_pass" -alias "$arg_ks_alias" 2> /dev/null)
		if [[ $ks_test == *"password was incorrect"* ]]; then
			log_err "Provided key password is incorrect"
			have_all_tools=false
		elif [[ $ks_test == *"does not exist"* ]]; then
			log_err "Provided alias name is incorrect"
			have_all_tools=false
		fi
	fi

	if [[ $have_all_tools == false ]]; then
		exit 1
	fi
}

handle_exit() {
	log_err "Terminated with Ctrl+C, removing temp files"
	if [[ -d "$decompiled_path" ]]; then rm -rf "$decompiled_path"; fi
	if [[ $source_file_ext_lower == "aab" ]] && [[ -f "$source_file_path/$source_file_name.apk" ]]; then rm "$source_file_path/$source_file_name.apk"; fi
	if [[ -f "$source_file_path/$source_file_name.apks" ]]; then rm "$source_file_path/$source_file_name.apks"; fi
	if [[ -d "$source_file_path/$source_file_name" ]]; then rm -rf "${source_file_path:?}/$source_file_name"; fi
	exit 1
}

log_err() {
	printf "${RED}[$prefix:ERROR] $*${NC}\n"
}

log_warn() {
	printf "${YELLOW}[$prefix:WARNING] $*${NC}\n"
}

log_info() {
	printf "${CYAN}[$prefix:INFO] $*${NC}\n"
}

parse_arguments() {
	new_args_list=()
	logging='/dev/tty'
	while [[ $# -gt 0 ]]; do
		case "$1" in
			-i|--install)
				arg_install_apk=1
				shift
				;;
			-p|--preserve)
				arg_preserve_catalog=1
				shift
				;;
			-r|--remove)
				arg_remove_source_file=1
				shift
				;;
			--pause)
				arg_pause_before_building=1
				shift
				;;
			-f|--file)
				arg_source_file="$2"
				shift
				shift
				;;
			-o|--output)
				arg_output="$2"
				shift
				shift
				;;
			-h|--help)
				arg_help=1
				shift
				;;
			-q|--quiet)
				logging='/dev/null'
				shift
				;;
			--ks)
				arg_ks="$2"
				shift
				shift
				;;
			--ks-pass)
				arg_ks_pass="$2"
				shift
				shift
				;;
			--ks-alias)
				arg_ks_alias="$2"
				shift
				shift
				;;
			--ks-key-pass)
				arg_ks_key_pass="$2"
				shift
				shift
				;;
			*)
				new_args_list+=("$1")
				shift
				;;
		esac
	done
}

print_usage() {
	script_name=$(basename "$0")
	printf "${BLACK}USAGE${NC}\n"
	printf "\t$script_name [-f|--file] /path/to/file/source_file [OPTIONS]\n"
	printf "\n"
	printf "${BLACK}DESCRIPTION${NC}\n"
	printf "\tThe script allows to bypass SSL pinning on Android >= 7 via rebuilding the APK file and making the user credential storage trusted. After processing the output APK file is ready for HTTPS traffic inspection.\n"
	printf "\tIf an AAB file provided the script creates a universal APK and processes it. If a XAPK file provided the script unzips it and processes every APK file.\n"
	printf "\n"
	printf "${BLACK}MANDATORY ARGUMENTS${NC}\n"
	printf "\t-f, --file\tAPK, AAB or XAPK file for rebuilding. Can be specified with the keys -f or --file or just with a file path\n"
	printf "\n"
	printf "${BLACK}OPTIONS${NC}\n"
	printf "\t-i, --install\tInstall the rebuilded APK file(s) via adb\n"
	printf "\t-p, --preserve\tPreserve the unpacked content of the APK file(s)\n"
	printf "\t-r, --remove\tRemove the source file (APK / AAB / XAPK), passed as the script argument, after rebuilding\n"
	printf "\t-o, --output\tOutput APK file name or output catalog path (in case of XAPK file)\n"
	printf "\t--ks\t\tUse custom keystore file for AAB decoding and APK signing\n"
	printf "\t--ks-pass\tPassword of the custom keystore\n"
	printf "\t--ks-alias\tKey (alias) in the custom keystore\n"
	printf "\t--ks-key-pass\tPassword for key (alias) in the custom keystore\n"
	printf "\t--pause\t\tPause the script execution before the building the output APK\n"
	printf "\t-q, --quiet\tDo not print messages from external tools\n"
	printf "\t-h, --help\tPrint this help message\n"
	printf "\n"
	printf "${BLACK}EXAMPLES${NC}\n"
	printf "\t$script_name /path/to/file/file_to_rebuild.apk -r -i -q\n"
	printf "\t./$script_name --file /path/to/file/file_to_rebuild.aab --remove --install\n"
	printf "\t./path/to/script/$script_name --pause -i -f /path/to/file/file_to_rebuild.xapk --ks /path/to/keystore/file.keystore --ks-pass password --ks-alias key_name --ks-key-pass password\n"
	printf "\t$script_name /path/to/file/file_to_rebuild.xapk --quiet -o /path/to/output/directory\n"
	printf "\t$script_name -f /path/to/file/file_to_rebuild.aab -o /path/to/output/file.apk -q\n"
}

rebuild_single_apk() {
	apk_path=$(dirname "$1")
	apk_name_with_ext=$(basename "$1")

	decompiled_path="$apk_path/$apk_name_with_ext-decompiled"

	log_info "Processing ${YELLOW}$apk_name_with_ext"
	log_info "Decompiling the apk file"
	java -jar "$apktool_path" decode "$apk_path/$apk_name_with_ext" --output "$decompiled_path" --no-src > $logging
	# java -jar "$apktool_path" decode --only-main-classes "$apk_path/$apk_name_with_ext" --output "$decompiled_path"

	nsc_file="$decompiled_path/res/xml/network_security_config.xml"
	log_info "Processing ${YELLOW}@xml/network_security_config.xml"

	if [[ ! -d "$decompiled_path/res/xml/" ]]; then
		mkdir -p "$decompiled_path/res/xml/"
	fi
	if [[ ! -f "$nsc_file" ]]; then
		touch "$nsc_file"
		{
			echo "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
			echo "<network-security-config>"
			echo "  <base-config cleartextTrafficPermitted=\"true\">"
			echo "    <trust-anchors>"
			echo "      <certificates src=\"system\" />"
			echo "      <certificates src=\"user\" />"
			echo "    </trust-anchors>"
			echo "  </base-config>"
			echo "</network-security-config>"
		} >> "$nsc_file"
	fi

	if [[ $(xmlstarlet sel -t -c "/network-security-config/base-config" "$nsc_file") == "" ]]; then
		xmlstarlet ed --inplace -s "/network-security-config" -t elem -n base-config "$nsc_file"
		xmlstarlet ed --inplace -a "/network-security-config/base-config" -t attr -n cleartextTrafficPermitted -v true "$nsc_file"
	elif [[ $(xmlstarlet sel -t -c "/network-security-config/base-config[@cleartextTrafficPermitted='true']" "$nsc_file") == "" ]]; then
		xmlstarlet ed --inplace -a "/network-security-config/base-config" -t attr -n cleartextTrafficPermitted -v true "$nsc_file"
	fi

	if [[ $(xmlstarlet sel -t -c "/network-security-config/base-config/trust-anchors" "$nsc_file") == "" ]]; then
		xmlstarlet ed --inplace -s "/network-security-config/base-config" -t elem -n trust-anchors "$nsc_file"
	fi

	for ca_type in "system" "user"; do
		if [[ $(xmlstarlet sel -t -c "/network-security-config/base-config/trust-anchors/certificates[@src='$ca_type']" "$nsc_file") == "" ]]; then
			xmlstarlet ed --inplace -s "/network-security-config/base-config/trust-anchors" -t elem -n certificates "$nsc_file"
			xmlstarlet ed --inplace -a "/network-security-config/base-config/trust-anchors/certificates[not(@src)]" -t attr -n src -v $ca_type "$nsc_file"
		fi	
	done

	log_info "Checking ${YELLOW}AndroidManifest.xml"
	if [[ $(xmlstarlet sel -t -c "/manifest/application[@android:networkSecurityConfig='@xml/network_security_config']" "$decompiled_path/AndroidManifest.xml") == "" ]]; then
		xmlstarlet ed --inplace -a "/manifest/application" -t attr -n android:networkSecurityConfig -v @xml/network_security_config "$decompiled_path/AndroidManifest.xml"
	fi

	if [[ $arg_pause_before_building == 1 ]]; then
		seconds_temp=$SECONDS
		log_info "Paused. Perform necessary actions and press ENTER to continue..."
		read
		SECONDS=$seconds_temp
	fi

	log_info "Building a new apk file"
	java -jar "$apktool_path" build "$decompiled_path" --use-aapt2 > $logging

	log_info "Signing the apk file"
	if [[ $arg_ks == '' ]]; then
		java -jar "$uber_apk_signer_path" \
			--apks "$decompiled_path/dist/$apk_name_with_ext" \
			--allowResign \
			--overwrite > $logging
	else
		java -jar "$uber_apk_signer_path" \
			--apks "$decompiled_path/dist/$apk_name_with_ext" \
			--allowResign \
			--ks "$ks_file_path/$ks_file_name" \
			--ksPass "$arg_ks_pass" \
			--ksAlias "$arg_ks_alias" \
			--ksKeyPass "$arg_ks_key_pass" \
			--overwrite > $logging
	fi

	if [[ $source_file_ext_lower == 'xapk' ]]; then
		mv "$decompiled_path/dist/$apk_name_with_ext" "$output_path/$apk_name_with_ext$filename_suffix.apk"
	else
		mv "$decompiled_path/dist/$apk_name_with_ext" "$output_path/$output_name_with_ext"
	fi

	if [[ $arg_preserve_catalog != 1 ]]; then
		log_info "Removing the unpacked content of the apk file ${YELLOW}$decompiled_path"
		rm -rf "$decompiled_path"
	fi
}

main() {
	parse_arguments "$@"
	set -- "${new_args_list[@]}"
	set_vars
	set_path

	if [[ $arg_source_file == "" ]]; then
		arg_source_file=$1
	fi

	if [[ $arg_source_file == "" ]] || { [[ $arg_help == 1 ]] && [[ $arg_source_file == "" ]]; }; then
		print_usage
		exit 0
	fi

	check_tools

	if [[ ! -f "$arg_source_file" ]]; then
		log_err "File $arg_source_file not found"
		exit 1
	fi

	source_file_path=$(cd "$(dirname "$arg_source_file")" && pwd)
	source_file_ext=${arg_source_file##*.}
	source_file_name=$(basename "$arg_source_file" ".$source_file_ext")
	source_file_ext_lower=$(echo "$source_file_ext" | awk '{print tolower($0)}')
	source_file_full_path="$source_file_path/$source_file_name.$source_file_ext"

	if [[ $arg_output == '' ]]; then
		if [[ $source_file_ext_lower == 'xapk' ]]; then
			output_path="$source_file_path/$source_file_name"
		else
			output_path="$source_file_path"
			output_name_with_ext="$source_file_name.$source_file_ext$filename_suffix.apk"
		fi
	else
		if [[ $source_file_ext_lower == 'xapk' ]]; then
			if [[ ! -d "$arg_output" ]]; then
				mkdir -p "$arg_output"
			fi
			output_path=$(cd "$arg_output" && pwd)
		else
			if [[ ! -d $(dirname "$arg_output") ]]; then
				mkdir -p "$(dirname "$arg_output")"
			fi
			output_path=$(cd "$(dirname "$arg_output")" && pwd)
			output_name_with_ext=$(basename "$arg_output")
		fi
	fi

	trap handle_exit SIGINT

	SECONDS=0

	case $source_file_ext_lower in
		"apk")
			rebuild_single_apk "$source_file_path/$source_file_name.$source_file_ext"
			;;
		"aab")
			log_info "Extracting apks from aab"
			if [[ $arg_ks == '' ]]; then
				java -jar "$bundletool_path" build-apks \
					--bundle="$source_file_full_path" \
					--output="$source_file_path/$source_file_name.apks" \
					--mode=universal > "$logging"
			else
				java -jar "$bundletool_path" build-apks \
					--bundle="$source_file_full_path" \
					--output="$source_file_path/$source_file_name.apks" \
					--ks="$ks_file_path/$ks_file_name" \
					--ks-pass=pass:"$arg_ks_pass" \
					--ks-key-alias="$arg_ks_alias" \
					--key-pass=pass:"$arg_ks_key_pass" \
					--mode=universal > "$logging"
			fi

			log_info "Extracting apk from apks"
			unzip "$source_file_path/$source_file_name.apks" -d "$source_file_path/$source_file_name" > $logging
			mv "$source_file_path/$source_file_name/universal.apk" "$source_file_path/$source_file_name.apk"

			log_info "Removing apks file and catalog"
			rm "$source_file_path/$source_file_name.apks"
			rm -rf "${source_file_path:?}/$source_file_name"

			rebuild_single_apk "$source_file_path/$source_file_name.apk"

			rm "$source_file_path/$source_file_name.apk"
			;;
		"xapk")
			log_info "Unzipping xapk"
			unzip "$source_file_full_path" -d "$source_file_path/$source_file_name" > $logging
			IFS=$'\n'
			log_info "Searching for apk files and processing them"
			for single_apk in $(find "$source_file_path/$source_file_name" -maxdepth 1 -name "*.apk"); do
				rebuild_single_apk "$single_apk"
				rm "$single_apk"
			done

			apks_list=""
			apks_list_for_log=""
			for single_apk in $(find "$output_path" -maxdepth 1 -name "*$filename_suffix.apk"); do
				apks_list="\"$single_apk\" $apks_list"
				apks_list_for_log="- $single_apk\n$apks_list_for_log"
			done
			;;
		*)
			log_err "Unknown file extension, expecting apk, aab or xapk"
			exit 1
			;;
	esac

	log_info "${GREEN}Rebuilded in $SECONDS seconds"

	if [[ $arg_remove_source_file == 1 ]]; then
		log_warn "Removing the source file $source_file_full_path"
		rm "$source_file_full_path"
	fi

	if [[ $arg_install_apk == 1 ]]; then
		if [[ $(which adb) == "" ]]; then
			log_err "adb is missing, add the path to adb to the PATH env var or install Android Studio or standalone platform tools"
		else
			if [[ $source_file_ext_lower == "xapk" ]]; then
				log_info "Installing the rebuilded apk files:\n${YELLOW}$apks_list_for_log"
				eval "adb install-multiple $apks_list"
			else
				log_info "Installing the rebuilded apk file ${YELLOW}$output_path/$output_name_with_ext"
				adb install "$output_path/$output_name_with_ext"
			fi
		fi
	fi
	if [[ $source_file_ext_lower == "xapk" ]]; then
		log_info "Output apk files for using in adb: ${YELLOW}$apks_list"
	else
		log_info "Output apk file for using in adb: ${YELLOW}\"$output_path/$output_name_with_ext\""
	fi
}

main "$@"
