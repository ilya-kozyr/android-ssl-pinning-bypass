# android-ssl-pinning-bypass
A python script (previously `bash`) that prepares Android APK (or AAB, XAPK) for HTTPS traffic inspection.

## Disclaimer
1. This script is not a "silver bullet" and even after using it you still might not be able to capture or decrypt the HTTPS traffic on Android. Learn tip #2 from the [Tips section](https://github.com/ilya-kozyr/android-ssl-pinning-bypass#tips).
2. The script is not fully tested yet upon migration to python. This point will be removed once the script will be tested.

## Features
The script allows to bypass SSL pinning on Android >= 7 via rebuilding the APK file and making the user credential storage trusted. After processing the output APK file is ready for HTTPS traffic inspection.

If an AAB file provided the script creates a universal APK and processes it. If a XAPK file provided the script unzips it and processes every APK file.
## Compatibility

Works on macOS, Linux and Windows.

[NEEDS TESTING] The performance on the Windows probably will be a few times (~3.5) lower than in macOS / Linux (`apktool` takes longer time to decode the APK).
## How the script works?

It:
- first of all checks if all the necessary tools are available and downloads it if it's not (except `java`);
- decodes the AAB file to APK file via `bundletool` (if AAB file provided) or unzips the XAPK file (in case of XAPK);
- decodes the APK file using `apktool`;
- patches (or creates if the file is missing) the app's `network_security_config.xml` to make user credential storage as trusted;
- encodes the new APK file via `apktool`;
- signs the patched APK file(s) via `uber-apk-signer`.

Optionally the script allow to:
- use the specific keystore for signing the output APK (by default the debug keystore is used);
- install the patched APK file(s) directly to the device via `adb`;
- preserve unpacked content of the input APK file(s);
- remove the source file (APK / AAB / XAPK) after patching;
- pause the script execution before the encoding the output APK file(s) in case you need to make any actions manually.

Root access is not required.
## Requirements
Install the tools from the list below:

- python >= 3.9
- pip
- java >= 8
- adb - can be installed with [Android Studio](https://developer.android.com/studio) (recommended) or [standalone package of the SDK platform tools](https://developer.android.com/studio/releases/platform-tools) (don't forget to add the path to the `adb` to the PATH environment variable)

The tools below will be downloaded by the script in case it's missing:
- [bundletool](https://github.com/google/bundletool/releases)
- [apktool](https://github.com/iBotPeaches/Apktool/releases)
- [uber-apk-signer](https://github.com/patrickfav/uber-apk-signer/releases)
## Usage
Preconditions:
1. Clone the repository
2. Execute the command `pip3 install -r requirements.txt` to install the required python modules

The script can be launched like
```
python3 /path/to/the/script/apk-rebuild.py
```

Execute  `python3 apk-rebuild.py -h` (or `python3 apk-rebuild.py --help`) to print the usage manual.
```
usage: apk-rebuild.py [-h] [-v] [-i] [--pause] [-p] [-r] [-o OUTPUT] [--no-src] [--only-main-classes] [--ks KS]
                      [--ks-pass KS_PASS] [--ks-alias KS_ALIAS] [--ks-alias-pass KS_ALIAS_PASS]
                      file

The script allows to bypass SSL pinning on Android >= 7 via rebuilding the APK file 
and making the user credential storage trusted. After processing the output APK file 
is ready for HTTPS traffic inspection.

positional arguments:
  file                  path to .apk, .aab or .xapk file for rebuilding

options:
  -h, --help            show this help message and exit
  -v, --version         show program's version number and exit
  -i, --install         install the rebuilded .apk file(s) via adb
  --pause               pause the script execution before the building the output .apk
  -p, --preserve        preserve the unpacked content of the .apk file(s)
  -r, --remove          remove the source file (.apk, .aab or .xapk) after the rebuilding
  -o OUTPUT, --output OUTPUT
                        output .apk file name or output directory path (for .xapk source file)
  --no-src              use --no-src option when decompiling via apktool
  --only-main-classes   use --only-main-classes option when decompiling via apktool
  --ks KS               use custom .keystore file for .aab decoding and .apk signing
  --ks-pass KS_PASS     password of the custom keystore
  --ks-alias KS_ALIAS   key (alias) in the custom keystore
  --ks-alias-pass KS_ALIAS_PASS
                        password for key (alias) in the custom keystore
```

For rebuilding the APK file use script with argument(s). The examples are below:
- patch the AAB file and do not delete the unpacked APK file content

  ```
  python3 apk-rebuild.py input.aab --preserve
  ```

- patch the APK file, remove the source APK file after patching and install the patched APK file on the Android-device

  ```
  python3 apk-rebuild.py input.apk -r -i
  ```

The path to the source file must be specified as the first argument.



## Tips
1. For easy capturing HTTPS traffic from development builds you can ask your developer to add the `<debug-overrides>` element to `the network_security_config.xml` (and add the `android:networkSecurityConfig` property to the `application` element in the `AndroidManifest.xml` of course): [https://developer.android.com/training/articles/security-config#debug-overrides](https://developer.android.com/training/articles/security-config#debug-overrides).
2. Learn [https://blog.nviso.eu/2020/11/19/proxying-android-app-traffic-common-issues-checklist/](https://blog.nviso.eu/2020/11/19/proxying-android-app-traffic-common-issues-checklist/), there are a lot of useful info about traffic capture on Android.
## Contribution
For bug reports, feature requests or discussing an idea, open an issue [here](https://github.com/ilya-kozyr/android-ssl-pinning-bypass/issues).
## Credits
Many thanks to:
- [Connor Tumbleson](https://github.com/iBotPeaches) for [apktool](https://github.com/iBotPeaches/Apktool)
- [Patrick Favre-Bulle](https://github.com/patrickfav) for [uber-apk-signer](https://github.com/patrickfav/uber-apk-signer)
- [Google](https://github.com/google) for [bundletool](https://github.com/google/bundletool)
