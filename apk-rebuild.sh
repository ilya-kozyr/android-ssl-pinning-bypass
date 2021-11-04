#!/bin/bash

# Requirements:
# bundletool - https://github.com/google/bundletool/releases
# apktool - https://github.com/iBotPeaches/Apktool/releases
# uber-apk-signer - https://github.com/patrickfav/uber-apk-signer/releases
# xmlstarlet - brew install xmlstarlet, http://xmlstar.sourceforge.net

set_vars() {
	NC=$'\e[0m'
	CYAN=$'\e[0;36m'
	RED=$'\e[0;31m'
	YELLOW=$'\e[0;33m'
	BLACK=$'\e[1m'
}

set_path() {
	# update "tools_path" to the actual path to the catalog with tools
	tools_path="$HOME/etc"
	bundletool_path="$tools_path/bundletool-all-1.8.0.jar"
	apktool_path="$tools_path/apktool_2.6.0.jar"
	apk_signer_path="$tools_path/uber-apk-signer-1.2.1.jar"
	keystore_path="$HOME/.android/debug.keystore"
}

check_tools() {
	have_all_tools=true
	if [ ! -f $bundletool_path ]; then
		echo "${RED}Bundletool not found, check the path in the script or download Bundletool at https://github.com/google/bundletool/releases"
		have_all_tools=false
	fi
	if [ ! -f $apktool_path ]; then
		echo "${RED}Apktool not found, check the path in the script or download Apktool at https://github.com/iBotPeaches/Apktool/releases"
		have_all_tools=false
	fi
	if [ ! -f $apk_signer_path ]; then
		echo "${RED}Apk_signer not found, check the path in the script or download Apk_signer at https://github.com/patrickfav/uber-apk-signer/releases"
		have_all_tools=false
	fi
	if [[ `which xmlstarlet` = "" ]]; then
		echo "${RED}xmlstarlet not found, install it via 'brew install xmlstarlet'"
		have_all_tools=false
	fi
	if [[ ! -f $keystore_path ]]; then
		echo "${RED}keystore file not found, specify the path in the script or install Android Studio"
		have_all_tools=false
	fi
	if [[ $have_all_tools = false ]]; then
		exit
	fi
}

print_usage() {
	script_name=`basename "$0"`
	echo -e "${BLACK}USAGE${NC}"
	echo -e "\t$script_name file [OPTIONS]"
	echo -e
	echo -e "${BLACK}DESCRIPTION${NC}"
	echo -e "\tThe script allows to bypass SSL pinning on Android > 6 via rebuilding the apk file (or making universal apk file from aab) and making the user credential storage trusted"
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

array_has_elem () {
	array=$1
	elem=$2
	[[ ${array[*]} =~ (^|[[:space:]])"$elem"($|[[:space:]]) ]] && echo 1 || echo 0
}

run () {
	SECONDS=0

	set_vars
	set_path

	if [[ $1 = "" ]]; then
		print_usage
		exit 1
	fi

	check_tools

	file_dir=$(cd "$(dirname "$1")" && pwd)
	cd "$file_dir"
	file_ext=${1##*.}
	file_name=$(basename "$1" ".$file_ext")

	if [[ $file_ext = "aab" ]]; then
		echo "${CYAN}Extracting apks from aab${NC}"
		java -jar $bundletool_path build-apks --bundle="$file_name.$file_ext" --output="$file_name.apks" --mode=universal

		echo "${CYAN}Extracting apk from apks and moving it${NC}"
		unzip "$file_name.apks" -d "$file_name"
		mv "$file_name/universal.apk" "$file_name.apk"

		echo "${CYAN}Removing apks file and catalog${NC}"
		rm "$file_name.apks"
		rm -rf "$file_name"
	elif [[ $file_ext != "apk" ]]; then
		echo "${RED}Unknown file extension${NC}"
		exit 1
	fi

	decompiled_path="$file_dir/$file_name.$file_ext-decompiled"

	echo "${CYAN}Decompiling the APK file${NC}"
	java -jar $apktool_path d -o "$decompiled_path" "$file_dir/$file_name.apk"
	# java -jar $apktool_path d --only-main-classes -o "$decompiled_path" "$file_dir/$file_name.apk"

	nsc_file="$decompiled_path/res/xml/network_security_config.xml"
	echo "${CYAN}Processing ${YELLOW}@xml/network_security_config.xml${NC}"

	if [ ! -d "$decompiled_path/res/xml/" ]; then
		mkdir "$decompiled_path/res/xml/"
	fi
	if [ ! -f "$nsc_file" ]; then
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

	if [[ `xmlstarlet sel -t -c "/network-security-config/base-config" "$nsc_file"` = "" ]]; then
		xmlstarlet ed --inplace -s "/network-security-config" -t elem -n base-config "$nsc_file"
		xmlstarlet ed --inplace -a "/network-security-config/base-config" -t attr -n cleartextTrafficPermitted -v true "$nsc_file"
	elif [[ `xmlstarlet sel -t -c "/network-security-config/base-config[@cleartextTrafficPermitted='true']" "$nsc_file"` = "" ]]; then
		xmlstarlet ed --inplace -a "/network-security-config/base-config" -t attr -n cleartextTrafficPermitted -v true "$nsc_file"
	fi

	if [[ `xmlstarlet sel -t -c "/network-security-config/base-config/trust-anchors" "$nsc_file"` = "" ]]; then
		xmlstarlet ed --inplace -s "/network-security-config/base-config" -t elem -n trust-anchors "$nsc_file"
	fi

	for ca_type in "system" "user"; do
		if [[ `xmlstarlet sel -t -c "/network-security-config/base-config/trust-anchors/certificates[@src='$ca_type']" "$nsc_file"` = "" ]]; then
			xmlstarlet ed --inplace -s "/network-security-config/base-config/trust-anchors" -t elem -n certificates "$nsc_file"
			xmlstarlet ed --inplace -a "/network-security-config/base-config/trust-anchors/certificates[not(@src)]" -t attr -n src -v $ca_type "$nsc_file"
		fi	
	done

	echo "${CYAN}Checking ${YELLOW}AndroidManifest.xml${NC}"
	if [[ `xmlstarlet sel -t -c "/manifest/application[@android:networkSecurityConfig='@xml/network_security_config']" "$decompiled_path/AndroidManifest.xml"` = "" ]]; then
		xmlstarlet ed --inplace -a "/manifest/application" -t attr -n android:networkSecurityConfig -v @xml/network_security_config "$decompiled_path/AndroidManifest.xml"
	fi

	if [[ `array_has_elem "$*" "--pause"` = 1 ]]; then
		echo "${CYAN}Paused. Perform necessary actions and press any key to continue ${NC}"
		read
	fi

	echo "${CYAN}Building new APK file${NC}"
	java -jar $apktool_path b "$decompiled_path" --use-aapt2

	echo "${CYAN}Signing APK file${NC}"
	java -jar $apk_signer_path -a "$decompiled_path/dist/$file_name.apk" --allowResign --overwrite

	mv "$decompiled_path/dist/$file_name.apk" "$decompiled_path.apk"
	if [[ $file_ext = "aab" ]]; then
		rm "$file_dir/$file_name.apk"
	fi

	echo "${CYAN}Done in $SECONDS seconds${NC}"

	if [[ `array_has_elem "$*" "-r"` = 1 ]] || [[ `array_has_elem "$*" "--remove"` = 1 ]]; then
		echo "${CYAN}Removing the source file $file_name.$file_ext${NC}"
		rm "$file_name.$file_ext"
	fi

	if [[ `array_has_elem "$*" "-p"` = 0 ]] && [[ `array_has_elem "$*" "--preserve"` = 0 ]]; then
		echo "${CYAN}Removing the unpacked content of the apk file $decompiled_path${NC}"
		rm -rf "$decompiled_path"
	fi

	if [[ `array_has_elem "$*" "-i"` = 1 ]] || [[ `array_has_elem "$*" "--install"` = 1 ]]; then
		echo "${CYAN}Installing the rebuilded apk file ${YELLOW}$decompiled_path.apk${NC}"
		if [[ `which adb` = "" ]]; then
			echo "${RED}adb not found, add the path to adb to the PATH env var or install Android Studio or standalone command line tools"
		else
			adb install "$decompiled_path.apk"
		fi
	fi

	echo "${CYAN}Output APK file: ${YELLOW}$decompiled_path.apk${NC}"
}

run "$@"