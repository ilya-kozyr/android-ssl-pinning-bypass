# android-ssl-pinning-bypass

A bash script that prepares Android APK (or AAB, XAPK) for HTTPS traffic inspection.

## Features
The script allows to bypass SSL pinning on Android >= 7 via rebuilding the APK file and making the user credential storage trusted. After processing the output APK file is ready for HTTPS traffic inspection.

If an AAB file provided the script creates a universal APK and processes it. If a XAPK file provided the script unzips it and processes every APK file.

Works on macOS and Linux. Raise a [ticket](https://github.com/ilya-kozyr/android-ssl-pinning-bypass/issues/new/choose) if you need a Windows version of the script.

## How the script works?

It:
- first of all checks if all the necessary tools are available and downloads it if it's not ([Homebrew](https://brew.sh/) should be installed for this);
- decodes the AAB file to APK file via `bundletool` (if AAB file provided) or unzips the XAPK file (in case of XAPK);
- decodes the APK file using `apktool`;
- patches (or creates if the file is missing) the app's `network_security_config.xml` via `xmlstarlet` to make user credential storage as trusted;
- encodes the new APK file via `apktool`;
- signs the patched APK file(s) via `uber-apk-signer`.

Optionally the script allow to:
- install the patched APK file(s) directly to the device via `adb`;
- preserve unpacked content of the input APK file(s);
- remove the source file (APK / AAB / XAPK) after patching;
- pause the script execution before the encoding the output APK file(s) in case you need to make any actions manually.

Root access is not required.
## Requirements
Install the tools from the list below:
- [Homebrew](https://brew.sh/)
- [xmlstarlet](http://xmlstar.sourceforge.net) - install via `brew install xmlstarlet`
- [adb](https://developer.android.com/studio) - can be installed with [Android Studio](https://developer.android.com/studio) (recommended) or [standalone package of the SDK platform tools](https://developer.android.com/studio/releases/platform-tools) (don't forget to add the path to the `adb` to the PATH environment variable)
- [keytool](https://docs.oracle.com/javase/8/docs/technotes/tools/unix/keytool.html) - install JDK from [Oracle](https://www.oracle.com/java/technologies/downloads/) or via `brew install openjdk`

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
- patch the AAB file and install it on the Android-device: `apk-rebuild.sh input.aab -i` or `apk-rebuild.sh input.aab --install`
- patch the APK file and remove the source APK file after patching: `apk-rebuild.sh input.apk -r` or `apk-rebuild.sh input.apk --remove`
- patch the APK file and do not delete the unpacked APK file content: `apk-rebuild.sh input.apk -p` or `apk-rebuild.sh input.apk --preserve`
- patch the AAB file and make a pause before encoding the output APK: `apk-rebuild.sh input.aab --pause`
- patch the APK file, remove the source APK file after patching and install the patched APK file on the Android-device: `apk-rebuild.sh input.apk -r -i`

Launch terminal and type `apk-rebuild.sh` without arguments to print the using manual.
```
USAGE
	apk-rebuild.sh file [OPTIONS]

DESCRIPTION
	The script allows to bypass SSL pinning on Android >= 7 via rebuilding the APK file and making the user credential storage trusted. After processing the output APK file is ready for HTTPS traffic inspection.
    If an AAB file provided the script creates a universal APK and processes it. If a XAPK file provided the script unzips it and processes every APK file.

	file	APK, AAB or XAPK file to rebuild

OPTIONS
	-i, --install	Install the rebuilded APK file(s) via 'adb install'
	-p, --preserve	Preserve the unpacked content of the APK file(s)
	-r, --remove	Remove the source file (APK / AAB / XAPK), passed as the script argument, after rebuilding
	--pause		Pause the script execution before the building the output APK

EXAMPLE
	apk-rebuild.sh /path/to/file/file_to_rebuild.apk -r -i
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
