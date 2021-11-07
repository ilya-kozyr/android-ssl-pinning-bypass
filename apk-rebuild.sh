#!/bin/bash

set_vars() {
	NC=$'\e[0m'
	CYAN=$'\e[0;36m'
	RED=$'\e[0;31m'
	YELLOW=$'\e[0;33m'
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
			log_msg "Downloading $tool_bin_name to $tools_catalog from $tool_bin_url"
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
			log_msg "Installing xmlstarlet"
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
				log_msg "Installing openjdk"
				brew install openjdk
			fi
		fi
		if [[ $(which keytool) == "" ]]; then
			have_all_tools=false
			log_err "Unable to install openjdk, install it manually"
		else
			if [[ ! -d "$keystore_catalog" ]]; then mkdir -p "$keystore_catalog"; fi
			log_msg "Generating keystore"
			keytool -genkey -v -keystore "$keystore_path" -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "C=US, O=Android, CN=Android Debug"
		fi
	fi

	if [[ $have_all_tools == false ]]; then
		exit 1
	fi
}

handle_exit() {
	log_err "Terminated with Ctrl+C, removing temp files"
	if [[ -d "$decompiled_path" ]]; then rm -rf "$decompiled_path"; fi
	if [[ $file_ext_lower == "aab" ]]; then rm "$file_dir/$file_name.apk"; fi
	if [[ -f "$file_name.apks" ]]; then rm "$file_name.apks"; fi
	if [[ -d "$file_name" ]]; then rm -rf "$file_name"; fi
	exit 1
}

log_err() {
	echo "${RED}[$prefix:ERROR] $*${NC}"
}

log_warn() {
	echo "${YELLOW}[$prefix:WARNING] $*${NC}"
}

log_msg() {
	echo "${CYAN}[$prefix:INFO] $*${NC}"
}

array_has_elem () {
	array=$1
	elem=$2
	[[ ${array[*]} =~ (^|[[:space:]])"$elem"($|[[:space:]]) ]] && echo 1 || echo 0
}

print_usage() {
	script_name=$(basename "$0")
	echo -e "${BLACK}USAGE${NC}"
	echo -e "\t$script_name file [OPTIONS]"
	echo -e
	echo -e "${BLACK}DESCRIPTION${NC}"
	echo -e "\tThe script allows to bypass SSL pinning on Android >= 7 via rebuilding the apk file (or making universal apk file from aab) and making the user credential storage trusted"
	echo -e
	echo -e "\tfile\tapk or aab file to rebuild"
	echo -e
	echo -e "${BLACK}OPTIONS${NC}"
	echo -e "\t-i, --install\tInstall the rebuilded apk file via 'adb install'"
	echo -e "\t-p, --preserve\tPreserve unpacked content of the input apk file"
	echo -e "\t-r, --remove\tRemove the source file after rebuilding"
	echo -e "\t--pause\t\tPause the script execution before the building the output apk"
	echo -e
	echo -e "${BLACK}EXAMPLE${NC}"
	echo -e "\t$script_name apk_to_rebuild.apk -r -i"
}

main () {
	SECONDS=0

	set_vars
	set_path

	if [[ $1 == "" ]]; then
		print_usage
		exit 1
	fi

	check_tools

	file_dir=$(cd "$(dirname "$1")" && pwd)
	cd "$file_dir"
	file_ext=${1##*.}
	file_ext_lower=$(echo $file_ext | awk '{print tolower($0)}')
	file_name=$(basename "$1" ".$file_ext")

	trap handle_exit SIGINT

	if [[ ! -f "$file_dir/$file_name.$file_ext" ]]; then
		log_err "File $file_dir/$file_name.$file_ext not found"
		exit 1
	fi

	if [[ $file_ext_lower == "aab" ]]; then
		log_msg "Extracting apks from aab"
		java -jar "$bundletool_path" build-apks --bundle="$file_name.$file_ext" --output="$file_name.apks" --mode=universal

		log_msg "Extracting apk from apks and moving it"
		unzip "$file_name.apks" -d "$file_name"
		mv "$file_name/universal.apk" "$file_name.apk"

		log_msg "Removing apks file and catalog"
		rm "$file_name.apks"
		rm -rf "$file_name"
	elif [[ $file_ext_lower != "apk" ]]; then
		log_err "Unknown file extension, expecting APK or AAB"
		exit 1
	fi

	decompiled_path="$file_dir/$file_name.$file_ext_lower-decompiled"

	log_msg "Decompiling the APK file"
	java -jar "$apktool_path" d -o "$decompiled_path" "$file_dir/$file_name.apk"
	# java -jar "$apktool_path" d --only-main-classes -o "$decompiled_path" "$file_dir/$file_name.apk"

	nsc_file="$decompiled_path/res/xml/network_security_config.xml"
	log_msg "Processing ${YELLOW}@xml/network_security_config.xml"

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

	log_msg "Checking ${YELLOW}AndroidManifest.xml"
	if [[ $(xmlstarlet sel -t -c "/manifest/application[@android:networkSecurityConfig='@xml/network_security_config']" "$decompiled_path/AndroidManifest.xml") == "" ]]; then
		xmlstarlet ed --inplace -a "/manifest/application" -t attr -n android:networkSecurityConfig -v @xml/network_security_config "$decompiled_path/AndroidManifest.xml"
	fi

	if [[ $(array_has_elem "$*" "--pause") == 1 ]]; then
		log_msg "Paused. Perform necessary actions and press any key to continue"
		read
	fi

	log_msg "Building new APK file"
	java -jar "$apktool_path" b "$decompiled_path" --use-aapt2

	log_msg "Signing APK file"
	java -jar "$apk_signer_path" -a "$decompiled_path/dist/$file_name.apk" --allowResign --overwrite

	mv "$decompiled_path/dist/$file_name.apk" "$decompiled_path.apk"
	if [[ $file_ext_lower == "aab" ]]; then
		rm "$file_dir/$file_name.apk"
	fi

	log_msg "Done in $SECONDS seconds"

	if [[ $(array_has_elem "$*" "-r") == 1 ]] || [[ $(array_has_elem "$*" "--remove") == 1 ]]; then
		log_warn "Removing the source file $file_name.$file_ext"
		rm "$file_name.$file_ext"
	fi

	if [[ $(array_has_elem "$*" "-p") == 0 ]] && [[ $(array_has_elem "$*" "--preserve") == 0 ]]; then
		log_msg "Removing the unpacked content of the apk file $decompiled_path"
		rm -rf "$decompiled_path"
	fi

	if [[ $(array_has_elem "$*" "-i") == 1 ]] || [[ $(array_has_elem "$*" "--install") == 1 ]]; then
		log_msg "Installing the rebuilded apk file $decompiled_path.apk"
		if [[ $(which adb) == "" ]]; then
			log_err "adb is missing, add the path to adb to the PATH env var or install Android Studio or standalone platform tools"
		else
			adb install "$decompiled_path.apk"
		fi
	fi

	log_msg "Output APK file: ${YELLOW}$decompiled_path.apk"
}

main "$@"
