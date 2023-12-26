#!/usr/bin/env python3

import platform, os, sys, colorama, ssl, glob, argparse, textwrap, time, shutil, subprocess, zipfile
from pathlib import Path
from signal import signal, SIGINT
from urllib import request
from lxml import etree

# enabling color for Windows CMD and PowerShell
colorama.init()
# bypass CERTIFICATE_VERIFY_FAILED error when downloading files
ssl._create_default_https_context = ssl._create_unverified_context

script_version = '1.0'
prefix = Path(sys.argv[0]).resolve().name
output_suffix = '-patched'
output_ext = '.apk'
decomp_dir_suffix = '-decompiled'
global start_time
global time_sum
time_sum = 0
global garbage
garbage = {'files': [], 'dirs': []}

class colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'



class tools:
    # path of home user directory
    home_path = str(Path.home())

    # path where apktool, bundletool and uder-apk-signer will be placed
    platforn_name = platform.system()
    if platforn_name == 'Darwin':
        tools_dir = Path(home_path).joinpath('Library', 'Application Support', 'apk-rebuild').resolve()
    elif platforn_name == 'Linux':
        tools_dir = Path(home_path).joinpath('.config', 'apk-rebuild').resolve()
    elif platforn_name == 'Windows':
        tools_dir = Path(os.getenv('APPDATA')).joinpath('apk-rebuild').resolve()

    # dictionary with tools data required to download it
    tools_data = [
        {
            'file_name': 'bundletool-all-',
            'version': '1.15.4',
            'url': 'https://github.com/google/bundletool/releases/download/',
            'name': 'bundletool'
        },
        {
            'file_name': 'apktool_',
            'version': '2.8.0',
            'url': 'https://github.com/iBotPeaches/Apktool/releases/download/v',
            'name': 'apktool'
        },
        {
            'file_name': 'uber-apk-signer-',
            'version': '1.2.1',
            'url': 'https://github.com/patrickfav/uber-apk-signer/releases/download/v',
            'name': 'uber-apk-signer'
        }
    ]

    # tools pathes
    bundletool_path = Path(tools_dir).joinpath(tools_data[0]['file_name'] + tools_data[0]['version'] + '.jar').resolve()
    apktool_path = Path(tools_dir).joinpath(tools_data[1]['file_name'] + tools_data[1]['version'] + '.jar').resolve()
    uber_apk_signer_path = Path(tools_dir).joinpath(tools_data[2]['file_name'] + tools_data[2]['version'] + '.jar').resolve()


class source_file:
    directory_path = ''
    name_wo_ext = ''
    ext = ''
    full_path = ''
    full_path_wo_ext = ''



class output_files:
    directory_path = ''
    full_path = ''



def exit_script(arg_code):
    colorama.deinit()
    sys.exit(arg_code)



def log_err(arg_msg):
    print(f'{colors.FAIL}[{prefix}:ERROR] {arg_msg}{colors.ENDC}')



def log_warn(arg_msg):
    print(f'{colors.WARNING}[{prefix}:WARNING] {arg_msg}{colors.ENDC}')



def log_succ(arg_msg):
    print(f'{colors.OKGREEN}[{prefix}:SUCCESS] {arg_msg}{colors.ENDC}')



def log_info(arg_msg):
    print(f'{colors.OKBLUE}[{prefix}:INFO] {arg_msg}{colors.ENDC}')



def check_tools():
    have_all_tools = True

    try:
        command_output = subprocess.run(['java', '-version'], stderr=subprocess.PIPE).stderr.decode('utf-8')
        if not 'build' in command_output.lower():
            have_all_tools = False
            log_err(f'java not found')
    except:
        have_all_tools = False
        log_err(f'java not found')

    log_info(f'Tools directory: {colors.WARNING}{tools.tools_dir}')
    # creating tools directory if it's missing
    Path(tools.tools_dir).mkdir(parents=True, exist_ok=True)

    # checking tools presence in a loop
    for tool in tools.tools_data:
        tool_file = Path(tools.tools_dir).joinpath(tool['file_name'] + tool['version'] + '.jar').resolve()
        tool_url = tool['url'] + tool['version'] + '/' + tool['file_name'] + tool['version'] + '.jar'
        # checking the single tool presence
        if not tool_file.exists():
            log_err(f"{tool['file_name']}{tool['version']} is missing")
            # removing previous versions of the tool if exists
            log_info(f"Removing previous versions of {tool['name']}")
            rm_files_list = Path(tools.tools_dir).glob(tool['file_name'] + '*')
            for rm_file_path in rm_files_list:
                try:
                    rm_file_path.unlink()
                except:
                    log_err(f'Error while deleting the file {rm_file_path}')
            # downloading the tool
            log_info(f"Downloading {tool['file_name']}{tool['version']}")
            request.urlretrieve(tool_url, tool_file)
            # recheck tool after downloading
            if not tool_file.exists():
                have_all_tools = False
                log_err(f"Unable to download {tool['file_name']}{tool['version']}")
    
    # keystore checking
    if not args.ks:
        debug_keystore_path = Path(tools.home_path).joinpath('.android').resolve()
        debug_keystore_path.mkdir(parents=True, exist_ok=True)
        debug_keystore_full_path = Path(debug_keystore_path).joinpath('debug.keystore').resolve()
        if not debug_keystore_full_path.exists():
            debug_keystore_source_full_path = Path(sys.argv[0]).parent.joinpath('debug.keystore').resolve()
            log_warn(f'File {debug_keystore_full_path} not found, copying it from {debug_keystore_source_full_path}')
            shutil.copyfile(debug_keystore_source_full_path, debug_keystore_full_path)
    else:
        if not Path(args.ks).resolve().exists():
            log_err(f'Keystore file {Path(args.ks).resolve()} not found')
            have_all_tools = False
        else:
            if not args.ks_pass or not args.ks_alias or not args.ks_alias_pass:
                if not args.ks_pass:
                    log_err(f'Keystore password is missing, specify it with --ks-pass argument')
                    have_all_tools = False
                if not args.ks_alias:
                    log_err(f'Keystore alias is missing, specify it with --ks-alias argument')
                    have_all_tools = False
                if not args.ks_alias_pass:
                    log_err(f'Key password is missing, specify it with --ks-key-pass argument')
                    have_all_tools = False
            else:
                command_output = subprocess.run(['keytool', '-J-Duser.language=en', '-list', '-keystore', str(Path(args.ks).resolve()) ,'-storepass', args.ks_pass, '-alias', args.ks_alias], stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout.decode('utf-8')
                if 'password was incorrect' in command_output:
                    log_err(f"Provided key password '{args.ks_pass}' is incorrect")
                    have_all_tools=False
                elif 'does not exist' in command_output:
                    log_err(f"Provided alias name '{args.ks_alias}' is not found")
                    have_all_tools=False

    if not have_all_tools:
        log_err('Some tools are missing, stopping the script')
        exit_script(1)



def handle_exit(signal_received, frame):
    log_warn('SIGINT or CTRL-C detected, removing temp files and directories')
    global garbage
    for single_file in garbage['files']:
        single_file.unlink(missing_ok=True)
    for single_dir in garbage['dirs']:
        shutil.rmtree(single_dir, ignore_errors=True)
    exit_script(0)



def rebuild_single_apk(arg_source_apk_full_path, arg_output_apk_full_path):
    # path of the directory, where .apk file will be decompiled
    decompiled_path = Path(str(arg_source_apk_full_path) + decomp_dir_suffix).resolve()
    global garbage
    garbage['dirs'].append(decompiled_path)

    # stop script if the directory already exists
    # most probably script was already executed, but not overwriting the directory to not lose files if it's not
    if decompiled_path.exists():
        log_err(f'Directory {decompiled_path} already exists, probably the .apk file {arg_source_apk_full_path} was already processed by the script. Remove the directory and run the script again. Stopping the script')
        exit_script(1)

    # decompiling .apk file with apktool
    log_info(f'Processing {colors.WARNING}{Path(arg_source_apk_full_path).name}')
    log_info('Decompiling the .apk file')
    command = ['java', '-jar', str(tools.apktool_path), 'decode', str(arg_source_apk_full_path), '--output', str(decompiled_path)]
    for param in [args.no_src, args.only_main_classes]:
        if param:
            command.append(param)
    subprocess.run(command, stdout=sys.stdout, stderr=sys.stderr)

    # preparing vars for network_security_config.xml processing
    network_security_config_path = decompiled_path.joinpath('res', 'xml').resolve()
    network_security_config_full_path = network_security_config_path.joinpath('network_security_config.xml').resolve()

    # creating directory to avoid errors
    network_security_config_path.mkdir(parents=True, exist_ok=True)

    # processing network_security_config.xml
    if not network_security_config_full_path.exists():
        # creating a new network_security_config.xml if file doesn't exist
        log_warn('File /res/xml/network_security_config.xml not found, creating')
        root = etree.Element('network-security-config')
        root.append(etree.Element('base-config', cleartextTrafficPermitted='false'))
        root[0].append(etree.Element('trust-anchors'))
        root[0][0].append(etree.Element('certificates', src='system'))
        root[0][0].append(etree.Element('certificates', src='user'))
        etree.ElementTree(root).write(str(network_security_config_full_path), pretty_print=True, encoding='utf-8', xml_declaration=True)
    else:
        # reading network_security_config.xml
        parser = etree.XMLParser(remove_blank_text=True)
        tree = etree.parse(str(network_security_config_full_path), parser=parser)
        # if network_security_config.xml exists checking the presence of the necessary tags and attributes
        if tree.find("base-config/trust-anchors/certificates[@src='user']") == None:
            log_warn("File /res/xml/network_security_config.xml doesn't meet the requirements")
            root = tree.getroot()

            # checking the 'base-config' tag
            elem_base = tree.find('base-config')
            if elem_base == None:
                log_info('Adding element <base-config cleartextTrafficPermitted="false">')
                root.append(etree.Element('base-config', cleartextTrafficPermitted='false'))
                elem_base = tree.find('base-config')

            # checking the 'trust-anchors' tag
            elem_trust = tree.find('base-config/trust-anchors')
            if elem_trust == None:
                log_info('Adding element <trust-anchors>')
                elem_base.append(etree.Element('trust-anchors'))
                elem_trust = tree.find('base-config/trust-anchors')

            # checking the 'certificates' tags with 'src' attribute
            for ca_type in ['system', 'user']:
                if tree.find("base-config/trust-anchors/certificates[@src='" + ca_type + "']") == None:
                    log_info(f'Adding element <certificates src="{ca_type}">')
                    elem_trust.append(etree.Element('certificates', src=ca_type))

            # writing updated network_security_config.xml
            etree.ElementTree(root).write(str(network_security_config_full_path), pretty_print=True, encoding='utf-8', xml_declaration=True)
        else:
            log_succ("File /res/xml/network_security_config.xml meets the requirements")

    # processing AndroidManifest.xml
    android_manifest_full_path = decompiled_path.joinpath('AndroidManifest.xml').resolve()
    # reading AndroidManifest.xml
    parser = etree.XMLParser(remove_blank_text=True)
    tree = etree.parse(str(android_manifest_full_path), parser=parser)
    # checking AndroidManifest.xml
    if tree.find("application[@android:networkSecurityConfig='@xml/network_security_config']", {'android': 'http://schemas.android.com/apk/res/android'}) == None:
        log_warn(f"File AndroidManifest.xml doesn't meet the requirements")
        root = tree.getroot()
        elem_application = tree.find('application')
        log_info('Adding attribute android:networkSecurityConfig="@xml/network_security_config"')
        # updating 'application' tag
        elem_application.set('{http://schemas.android.com/apk/res/android}networkSecurityConfig', '@xml/network_security_config')
        # writing AndroidManifest.xml
        etree.ElementTree(root).write(str(android_manifest_full_path), pretty_print=True, encoding='utf-8', xml_declaration=True)
    else:
        log_succ(f'File AndroidManifest.xml meets the requirements')

    # processing '--pause' argument
    if args.pause:
        global start_time
        global time_sum
        # stopping timer
        time_sum += (time.time() - start_time)
        log_info('Paused. Perform necessary actions and press ENTER to continue')
        input('')
        # continue timer
        start_time = time.time()

    # building a new .apk file with apktool
    log_info('Building a new .apk file')
    command = ['java', '-jar', str(tools.apktool_path), 'build', str(decompiled_path), '--use-aapt2', '--output', str(arg_output_apk_full_path)]
    subprocess.run(command, stdout=sys.stdout, stderr=sys.stderr)
    garbage['files'].append(arg_output_apk_full_path)

    # sign the new .apk file with uber-apk-signer
    log_info('Signing the new .apk file')
    command = ['java', '-jar', str(tools.uber_apk_signer_path), '--apks', str(arg_output_apk_full_path), '--allowResign', '--overwrite']
    if args.ks:
        command.extend(['--ks', args.ks, '--ksPass', args.ks_pass, '--ksAlias', args.ks_alias, '--ksKeyPass', args.ks_alias_pass])
    subprocess.run(command, stdout=sys.stdout, stderr=sys.stderr)

    # removing the decompiled directory if atgument '--preserve' was not provided
    if not args.preserve:
        log_info(f'Removing decompiled directory {colors.WARNING}{decompiled_path}')
        shutil.rmtree(decompiled_path, ignore_errors=True)



def main():
    # handle Ctrl+C
    signal(SIGINT, handle_exit)

    # var for garage files and directories
    global garbage

    # parse script arguments
    parser = argparse.ArgumentParser(description='The script allows to bypass SSL pinning on Android >= 7 via rebuilding the APK file and making the user credential storage trusted. After processing the output APK file is ready for HTTPS traffic inspection.')
    parser.add_argument('source_file', metavar='file', help='path to .apk, .aab or .xapk file for rebuilding')
    parser.add_argument('-v', '--version', action='version', version=f'%(prog)s {script_version}')
    parser.add_argument('-i', '--install', action='store_true', help='install the rebuilded .apk file(s) via adb')
    parser.add_argument('--pause', action='store_true', help='pause the script execution before the building the output .apk')
    parser.add_argument('-p', '--preserve', action='store_true', help='preserve the unpacked content of the .apk file(s)')
    parser.add_argument('-r', '--remove', action='store_true', help='remove the source file (.apk, .aab or .xapk) after the rebuilding')
    parser.add_argument('-o', '--output', help='output .apk file name or output directory path (for .xapk source file)')
    parser.add_argument('--no-src', action='store_const', const='--no-src', help='use --no-src option when decompiling via apktool')
    parser.add_argument('--only-main-classes', action='store_const', const='--only-main-classes', help='use --only-main-classes option when decompiling via apktool')
    parser.add_argument('--ks', help='use custom .keystore file for .aab decoding and .apk signing')
    parser.add_argument('--ks-pass', help='password of the custom keystore')
    parser.add_argument('--ks-alias', help='key (alias) in the custom keystore')
    parser.add_argument('--ks-alias-pass', help='password for key (alias) in the custom keystore')
    global args
    args = parser.parse_args()

    log_info(f'Script version: {script_version}')
    log_info(f'Python version: {sys.version}')

    # stop script if source file doesn't exists
    if not Path(args.source_file).resolve().exists():
        log_err(f'File {Path(args.source_file).resolve()} not found, stopping the script')
        exit_script(1)

    # check if all necessary tools are available
    check_tools()

    # get necessary data about the source file
    source_file.ext = Path(args.source_file).resolve().suffix
    source_file.name_wo_ext = Path(args.source_file).resolve().stem
    source_file.directory_path = Path(args.source_file).resolve().parent
    source_file.full_path = Path(args.source_file).resolve()
    source_file.full_path_wo_ext = source_file.full_path.with_suffix('')

    # generate pathes for output file(s)
    if args.output != None:
        if source_file.ext.lower() == '.xapk':
            output_files.directory_path = Path(args.output).resolve()
            Path(output_files.directory_path).mkdir(parents=True, exist_ok=True)
        else:
            output_files.directory_path = Path(args.output).parent.resolve()
            Path(output_files.directory_path).mkdir(parents=True, exist_ok=True)
            output_files.full_path = Path(str(Path(args.output).resolve()) + output_suffix + output_ext).resolve()
    else:
        if source_file.ext.lower() == '.xapk':
            output_files.directory_path = Path(source_file.directory_path).joinpath(source_file.name_wo_ext)
        else:
            output_files.directory_path = source_file.directory_path
            output_files.full_path = Path(str(source_file.full_path_wo_ext) + output_suffix + output_ext).resolve()

    # source file processing start time
    global start_time
    start_time = time.time()

    # processing the source file depending on it extension
    if source_file.ext.lower() == '.apk':
        # rebuilding .apk
        rebuild_single_apk(source_file.full_path, output_files.full_path)
    elif source_file.ext.lower() == '.aab':
        # extracting .apks from .apk with bundletool
        log_info(f'Extracting .apks from {colors.WARNING}{source_file.full_path}')
        apks_full_path = source_file.full_path.with_suffix('.apks')
        garbage['files'].append(apks_full_path)
        command = ['java', '-jar', str(tools.bundletool_path), 'build-apks', '--bundle=' + str(source_file.full_path), '--output=' + str(apks_full_path), '--mode=universal']
        # execute bundletool
        subprocess.run(command, stdout=sys.stdout, stderr=sys.stderr)

        # extracting .apk from .apks
        log_info(f'Extracting .apk from {colors.WARNING}{str(apks_full_path)}')
        apks_dir_full_path = source_file.directory_path.joinpath(source_file.name_wo_ext).resolve()
        garbage['dirs'].append(apks_dir_full_path)
        with zipfile.ZipFile(apks_full_path, 'r') as zip_ref:
            zip_ref.extractall(apks_dir_full_path)
        # remove .apks file
        apks_full_path.unlink()
        # move .apk file
        apk_full_path = source_file.full_path.with_suffix('.apk')
        garbage['files'].append(apk_full_path)
        shutil.move(apks_dir_full_path.joinpath('universal.apk').resolve(), apk_full_path)
        # remove unzipped directory
        shutil.rmtree(apks_dir_full_path, ignore_errors=True)

        # rebuild .apk
        rebuild_single_apk(apk_full_path, output_files.full_path)

        # removing .apk
        apk_full_path.unlink()
    elif source_file.ext.lower() == '.xapk':
        # extracting .xapk
        log_info(f'Extracing .xapk')
        xapk_dir_full_path = output_files.directory_path
        garbage['dirs'].append(xapk_dir_full_path)
        with zipfile.ZipFile(source_file.full_path, 'r') as zip_ref:
            zip_ref.extractall(xapk_dir_full_path)

        # searching for .apk files
        log_info(f'Searching for .apk files in {colors.WARNING}{xapk_dir_full_path}')
        apk_files_list = Path(xapk_dir_full_path).glob('*.apk'.lower())
        new_apk_list = []
        for single_apk in apk_files_list:
            single_apk_new = xapk_dir_full_path.joinpath(str(Path(single_apk.name).with_suffix('')) + output_suffix + output_ext).resolve()
            rebuild_single_apk(single_apk, single_apk_new)
            new_apk_list.append(single_apk_new)
            single_apk.unlink()
    else:
        log_err('Unsupported file extension. The script supports .apk, .aab, .xapk')
        exit_script(1)

    # logging time spent for rebuilding source file
    global time_sum
    time_sum += (time.time() - start_time)
    log_succ(f'Rebuilded in {int(time_sum)} seconds')

    # check and removing the source file
    if args.remove:
        log_info(f'Removing the source file {colors.WARNING}{source_file.full_path}')
        source_file.full_path.unlink()

    if args.install:
        command_output = subprocess.run(['adb', '--version'], stdout=subprocess.PIPE).stdout.decode('utf-8')
        if 'debug' in command_output.lower():
            if source_file.ext.lower() == '.xapk':
                log_info(f'Installing the rebuilded apk files:')
                command = ['adb', 'install-multiple']
                for single_apk in new_apk_list:
                    print(f'{colors.WARNING}{single_apk}{colors.ENDC}')
                    command.append(str(single_apk))
                subprocess.run(command, stdout=sys.stdout, stderr=sys.stderr)
            else:
                log_info(f'Installing the rebuilded .apk file {colors.WARNING}{output_files.full_path}')
                command = ['adb', 'install', str(output_files.full_path)]
                subprocess.run(command, stdout=sys.stdout, stderr=sys.stderr)
        else:
            log_err("adb not found, unable to execute the 'adb install' command")
    
    if source_file.ext.lower() == '.xapk':
        str_apk_list = ''
        for single_apk in new_apk_list:
            str_apk_list += f'"{str(single_apk)}" '
        log_info(f'Command for installing: {colors.OKGREEN}adb install-multiple {str_apk_list}')
    else:
        log_info(f'Command for installing: {colors.OKGREEN}adb install "{str(output_files.full_path)}"')

    # script end
    exit_script(0)



if __name__ == '__main__':
    main()
