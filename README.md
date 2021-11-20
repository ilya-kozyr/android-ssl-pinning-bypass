# android-ssl-pinning-bypass

A bash script that prepares Android APK (or AAB, XAPK) for HTTPS traffic inspection.

## Features
The script allows to bypass SSL pinning on Android >= 7 via rebuilding the APK file and making the user credential storage trusted. After processing the output APK file is ready for HTTPS traffic inspection.

If an AAB file provided the script creates a universal APK and processes it. If a XAPK file provided the script unzips it and processes every APK file.
## Compatibility

Works on macOS and Linux.

On Windows 10 / 11 the script can be used with Windows Subsystem for Linux. For this:
1. Install WSL with help of, e.g. [this guide](https://www.thewindowsclub.com/how-to-run-sh-or-shell-script-file-in-windows-10).
2. Install the [Ubuntu](https://www.microsoft.com/en-us/p/ubuntu/9nblggh4msv6) from the Microsoft Store. Then launch Ubuntu app and let it config itself and then create a user.
3. Install `xmlstarlet` and `openjdk-17-jre` via `apt-get install`.
4. Use script in the terminal, easier in the Ubuntu app.

The performance on the Windows probably will be a few times (~3.5) lower than in macOS / Linux (`apktool` takes longer time to decode the APK).
## How the script works?

It:
- first of all checks if all the necessary tools are available and downloads it if it's not ([Homebrew](https://brew.sh/) should be installed for this);
- decodes the AAB file to APK file via `bundletool` (if AAB file provided) or unzips the XAPK file (in case of XAPK);
- decodes the APK file using `apktool`;
- patches (or creates if the file is missing) the app's `network_security_config.xml` via `xmlstarlet` to make user credential storage as trusted;
- encodes the new APK file via `apktool`;
- signs the patched APK file(s) via `uber-apk-signer`.

Optionally the script allow to:
- use the specific keystore for signing the output APK;
- install the patched APK file(s) directly to the device via `adb`;
- preserve unpacked content of the input APK file(s);
- remove the source file (APK / AAB / XAPK) after patching;
- pause the script execution before the encoding the output APK file(s) in case you need to make any actions manually.

Root access is not required.
## Requirements
Install the tools from the list below:
- [Homebrew](https://brew.sh/) - package manager, required in case `xmlstarlet` or keystore file are missing 
- [xmlstarlet](http://xmlstar.sourceforge.net) - install via `brew install xmlstarlet`
- [adb](https://developer.android.com/studio) - can be installed with [Android Studio](https://developer.android.com/studio) (recommended) or [standalone package of the SDK platform tools](https://developer.android.com/studio/releases/platform-tools) (don't forget to add the path to the `adb` to the PATH environment variable)
- [keytool](https://docs.oracle.com/javase/8/docs/technotes/tools/unix/keytool.html) - required in case keystore file is missing, install via `brew install openjdk`

The tools below will be downloaded by the script in case it's missing:
- [bundletool](https://github.com/google/bundletool/releases)
- [apktool](https://github.com/iBotPeaches/Apktool/releases)
- [uber-apk-signer](https://github.com/patrickfav/uber-apk-signer/releases)
## Usage
### Preconditions
1. Clone the repository, add the path to the catalog with `.sh` script to the `PATH` environment variable
2. Add the execution permissions to the script via `chmod +x apk-rebuild.sh`
### Usage
The script can be launched like:
- `apk-rebuild.sh` - in case the execution permissions were added and the script's location is in the PATH environment variable;
- `/path/to/the/script/apk-rebuild.sh` - in case the execution permissions were added, but the script's location is not in the PATH environment variable;
- `sh /path/to/the/script/apk-rebuild.sh` - in case the execution permissions were not added and the script's location is not in the PATH environment variable.

For rebuilding the APK file use script with argument(s). The examples are below:
- patch the AAB file and install it on the Android-device: `apk-rebuild.sh -f input.aab -i` or `apk-rebuild.sh --file input.aab --install`
- patch the APK file and remove the source APK file after patching: `apk-rebuild.sh Downloads/input.apk -r` or `apk-rebuild.sh input.apk --remove`
- patch the APK file and do not delete the unpacked APK file content: `apk-rebuild.sh input.apk -p` or `apk-rebuild.sh input.apk --preserve`
- patch the AAB file and make a pause before encoding the output APK: `apk-rebuild.sh input.aab --pause`
- patch the APK file, remove the source APK file after patching and install the patched APK file on the Android-device: `apk-rebuild.sh input.apk -r -i`

The path to the source file can be specified with the argument with key `-f file.apk` or `--file file.apk` or with argument without the key `file.apk`.

Launch terminal and type `apk-rebuild.sh` without arguments (or `apk-rebuild.sh -h`, or `apk-rebuild.sh --help`) to print the usage manual.
```
USAGE
	apk-rebuild.sh [-f|--file] /path/to/file/source_file [OPTIONS]

DESCRIPTION
	The script allows to bypass SSL pinning on Android >= 7 via rebuilding the APK file and making the user credential storage trusted. After processing the output APK file is ready for HTTPS traffic inspection.
	If an AAB file provided the script creates a universal APK and processes it. If a XAPK file provided the script unzips it and processes every APK file.

MANDATORY ARGUMENTS
	-f, --file	APK, AAB or XAPK file for rebuilding. Can be specified with the keys -f or --file or just with a file path

OPTIONS
	-i, --install	Install the rebuilded APK file(s) via adb
	-p, --preserve	Preserve the unpacked content of the APK file(s)
	-r, --remove	Remove the source file (APK / AAB / XAPK), passed as the script argument, after rebuilding
	-o, --output	Output APK file name or output catalog path (in case of XAPK file)
	--ks			Use custom keystore file for AAB decoding and APK signing
	--ks-pass		Password of the custom keystore
	--ks-alias		Key (alias) in the custom keystore
	--ks-key-pass	Password for key (alias) in the custom keystore
	--pause			Pause the script execution before the building the output APK
	-q, --quiet		Do not print messages from external tools
	-h, --help		Print this help message

EXAMPLES
	apk-rebuild.sh /path/to/file/file_to_rebuild.apk -r -i -q
	sh apk-rebuild.sh --file /path/to/file/file_to_rebuild.aab --remove --install
	sh /path/to/script/apk-rebuild.sh --pause -i -f /path/to/file/file_to_rebuild.xapk --ks /path/to/keystore/file.keystore --ks-pass password --ks-alias key_name --ks-key-pass password
	apk-rebuild.sh /path/to/file/file_to_rebuild.xapk --quiet -o /path/to/output/directory
	apk-rebuild.sh -f /path/to/file/file_to_rebuild.aab -o /path/to/output/file.apk -q
```

## Tip
For easy capturing HTTPS traffic from development builds you can ask your developer to add the `<debug-overrides>` element to `the network_security_config.xml` (and add the `android:networkSecurityConfig` property to the `application` element in the `AndroidManifest.xml` of course): [https://developer.android.com/training/articles/security-config#debug-overrides](https://developer.android.com/training/articles/security-config#debug-overrides).
## Contribution
For bug reports, feature requests or discussing an idea, open an issue [here](https://github.com/ilya-kozyr/android-ssl-pinning-bypass/issues).
## Credits
Many thanks to:
- [Connor Tumbleson](https://github.com/iBotPeaches) for [apktool](https://github.com/iBotPeaches/Apktool)
- [Patrick Favre-Bulle](https://github.com/patrickfav) for [uber-apk-signer](https://github.com/patrickfav/uber-apk-signer)
- [Google](https://github.com/google) for [bundletool](https://github.com/google/bundletool/releases)
