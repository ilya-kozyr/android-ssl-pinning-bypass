#!/bin/bash

set_vars() {
	NC=$'\e[0m'
	CYAN=$'\e[0;36m'
	RED=$'\e[0;31m'
	YELLOW=$'\e[0;33m'
	GREEN=$'\e[0;32m'
	BLACK=$'\e[1m'
	prefix=$(basename "$0")
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
	apk_signer_path="$tools_catalog/${tools[8]}${tools[9]}.jar"
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
			find $tools_catalog -name "${tools[i+3]}*.jar" -delete
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

	if [[ $have_all_tools == false ]]; then
		exit 1
	fi
}

handle_exit() {
	log_err "Terminated with Ctrl+C, removing temp files"
	if [[ -d "$decompiled_path" ]]; then rm -rf "$decompiled_path"; fi
	if [[ $source_file_ext_lower == "aab" ]]; then rm "$source_file_path/$source_file_name.apk"; fi
	if [[ -f "$source_file_name.apks" ]]; then rm "$source_file_name.apks"; fi
	if [[ -d "$source_file_path/$source_file_name" ]]; then rm -rf "$source_file_path/$source_file_name"; fi
	exit 1
}

log_err() {
	echo -e "${RED}[$prefix:ERROR] $*${NC}"
}

log_warn() {
	echo -e "${YELLOW}[$prefix:WARNING] $*${NC}"
}

log_info() {
	echo -e "${CYAN}[$prefix:INFO] $*${NC}"
}

parse_arguments() {
	new_args_list=()
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
			-h|--help)
				arg_help=1
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
	echo -e "${BLACK}USAGE${NC}"
	echo -e "\t$script_name [-f|--file] /path/to/file/source_file [OPTIONS]"
	echo -e
	echo -e "${BLACK}DESCRIPTION${NC}"
	echo -e "\tThe script allows to bypass SSL pinning on Android >= 7 via rebuilding the APK file and making the user credential storage trusted. After processing the output APK file is ready for HTTPS traffic inspection."
	echo -e "\tIf an AAB file provided the script creates a universal APK and processes it. If a XAPK file provided the script unzips it and processes every APK file."
	echo -e
	echo -e "${BLACK}MANDATORY ARGUMENTS${NC}"
	echo -e "\t-f, --file\tAPK, AAB or XAPK file for rebuilding. Can be specified with the keys -f or --file or just with a file path"
	echo -e
	echo -e "${BLACK}OPTIONS${NC}"
	echo -e "\t-i, --install\tInstall the rebuilded APK file(s) via adb"
	echo -e "\t-p, --preserve\tPreserve the unpacked content of the APK file(s)"
	echo -e "\t-r, --remove\tRemove the source file (APK / AAB / XAPK), passed as the script argument, after rebuilding"
	echo -e "\t--pause\t\tPause the script execution before the building the output APK"
	echo -e "\t-h, --help\tPrint this help message"
	echo -e
	echo -e "${BLACK}EXAMPLES${NC}"
	echo -e "\t$script_name /path/to/file/file_to_rebuild.apk -r -i"
	echo -e "\t$script_name --file /path/to/file/file_to_rebuild.aab --remove --install"
	echo -e "\t$script_name --pause -i -f /path/to/file/file_to_rebuild.xapk"
	echo -e "\t$script_name /path/to/file/file_to_rebuild.xapk"
}

rebuild_single_apk() {
	apk_path=$(dirname "$1")
	apk_name=$(basename "$1")

	decompiled_path="$apk_path/$apk_name-decompiled"

	log_info "Processing ${YELLOW}$apk_name"
	log_info "Decompiling the apk file"
	java -jar "$apktool_path" d -o "$decompiled_path" "$apk_path/$apk_name"
	# java -jar "$apktool_path" d --only-main-classes -o "$decompiled_path" "$apk_path/$apk_name"

	nsc_file="$decompiled_path/res/xml/network_security_config.xml"
	log_info "Processing ${YELLOW}@xml/network_security_config.xml"

	if [[ ! -d "$decompiled_path/res/xml/" ]]; then
		mkdir -p "$decompiled_path/res/xml/"
	fi
	if [[ ! -f "$nsc_file" ]]; then
		echo "<?xml version=\"1.0\" encoding=\"utf-8\"?>" > "$nsc_file"
		echo "<network-security-config>" >> "$nsc_file"
		echo "  <base-config cleartextTrafficPermitted=\"true\">" >> "$nsc_file"
		echo "    <trust-anchors>" >> "$nsc_file"
		echo "      <certificates src=\"system\" />" >> "$nsc_file"
		echo "      <certificates src=\"user\" />" >> "$nsc_file"
		echo "    </trust-anchors>" >> "$nsc_file"
		echo "  </base-config>" >> "$nsc_file"
		echo "</network-security-config>" >> "$nsc_file"
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
		log_info "Paused. Perform necessary actions and press ENTER to continue..."
		read
	fi

	log_info "Building a new apk file"
	java -jar "$apktool_path" b "$decompiled_path" --use-aapt2

	log_info "Signing the apk file"
	java -jar "$apk_signer_path" -a "$decompiled_path/dist/$apk_name" --allowResign --overwrite

	mv "$decompiled_path/dist/$apk_name" "$apk_path/$apk_name-patched.apk"
	apk_to_install="\"$apk_path/$apk_name-patched.apk\""

	if [[ $arg_preserve_catalog != 1 ]]; then
		log_info "Removing the unpacked content of the apk file ${YELLOW}$decompiled_path"
		rm -rf "$decompiled_path"
	fi
}

main () {
	parse_arguments "$@"
	set -- "${new_args_list[@]}"
	set_vars
	set_path

	if [[ $arg_source_file == "" ]]; then
		arg_source_file=$1
	fi

	if [[ $arg_source_file == "" ]] || ([[ $arg_help == 1 ]] && [[ $arg_source_file == "" ]]); then
		print_usage
		exit 0
	elif [[ ! -f "$arg_source_file" ]]; then
		log_err "File $arg_source_file not found"
		exit 1
	fi

	check_tools

	source_file_path=$(cd "$(dirname "$arg_source_file")" && pwd)
	source_file_ext=${arg_source_file##*.}
	source_file_name=$(basename "$arg_source_file" ".$source_file_ext")
	source_file_ext_lower=$(echo $source_file_ext | awk '{print tolower($0)}')
	source_file_full_path="$source_file_path/$source_file_name.$source_file_ext"

	trap handle_exit SIGINT

	SECONDS=0

	case $source_file_ext_lower in
		"apk")
			rebuild_single_apk "$source_file_path/$source_file_name.apk" "${@:2}"
			;;
		"aab")
			log_info "Extracting apks from aab"
			java -jar "$bundletool_path" build-apks --bundle="$source_file_full_path" --output="$source_file_path/$source_file_name.apks" --mode=universal

			log_info "Extracting apk from apks and moving it"
			unzip "$source_file_path/$source_file_name.apks" -d "$source_file_path/$source_file_name"
			mv "$source_file_path/$source_file_name/universal.apk" "$source_file_path/$source_file_name.apk"

			log_info "Removing apks file and catalog"
			rm "$source_file_path/$source_file_name.apks"
			rm -rf "$source_file_path/$source_file_name"

			rebuild_single_apk "$source_file_path/$source_file_name.apk" "${@:2}"

			rm "$source_file_path/$source_file_name.apk"
			;;
		"xapk")
			log_info "Unzipping xapk"
			unzip "$source_file_full_path" -d "$source_file_path/$source_file_name"
			IFS=$'\n'
			log_info "Searching for apk files and processing them"
			for single_apk in $(find "$source_file_path/$source_file_name" -maxdepth 1 -name "*.apk"); do
				rebuild_single_apk "$single_apk" "${@:2}"
				rm "$single_apk"
			done

			apks_list=""
			apks_list_for_log=""
			for single_apk in $(find "$source_file_path/$source_file_name" -maxdepth 1 -name "*-patched.apk"); do
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
			if [[ $source_file_ext_lower == "aab" ]] || [[ $source_file_ext_lower == "apk" ]]; then
				log_info "Installing the rebuilded apk file ${YELLOW}$apk_to_install"
				adb install "$apk_path/$apk_name-patched.apk"
			elif [[ $source_file_ext_lower == "xapk" ]]; then
				log_info "Installing the rebuilded apk files:\n${YELLOW}$apks_list_for_log"
				eval "adb install-multiple $apks_list"
			fi
		fi
	else
		if [[ $source_file_ext_lower == "aab" ]] || [[ $source_file_ext_lower == "apk" ]]; then
			log_info "Output apk file for using in adb: ${YELLOW}$apk_to_install"
		elif [[ $source_file_ext_lower == "xapk" ]]; then
			log_info "Output apk files for using in adb: ${YELLOW}$apks_list"
		fi
	fi
}

main "$@"
