## sudo apt-get install python3-pyatspi
## https://blog.csdn.net/Lcicada_2021/article/details/117307293
import pyatspi
import locale
import argparse
import time

def get_drive_label(drive_letter):
    try:
        # 在Linux下，可以使用lsblk命令来获取磁盘信息
        import subprocess
        output = subprocess.check_output(['lsblk', '-o', 'NAME,LABEL']).decode('utf-8')
        for line in output.split('\n'):
            if drive_letter in line:
                return line.split()[1]
    except Exception as e:
        return str(e)

def get_folder_path_for_pyatspi(input_path):
    default_locale = locale.getdefaultlocale()
    drive_letter = input_path[0]  # Extract the drive letter
    drive_name = get_drive_label(drive_letter)
    drive = f"{drive_name}({drive_letter}:)"

    if default_locale[0] == 'zh_CN':
        users = '用户'
        desktop = '桌面'
        this_computer = '此电脑'
    else:
        users = 'Users'
        desktop = 'Desktop'
        this_computer = 'This PC'
    path_parts = input_path.split('/')
    if 'Desktop' in path_parts:
        if default_locale[0] == 'zh_CN':
            path_parts[path_parts.index('Desktop')] = '桌面'
            path_parts[path_parts.index('Users')] = '用户'
    pyatspi_path = [desktop, this_computer, drive] + path_parts[1:]
    pyatspi_path_formatted = [f'{part}' for part in pyatspi_path]
    return pyatspi_path_formatted

def auto_mbconvert(MB_BOLD_path, R_BOLD_path, O_BOLD_path, output_filename):
    default_locale = locale.getdefaultlocale()
    if default_locale[0] == 'zh_CN':
        dialog_title = "浏览文件夹"
        confirm_button_text = "确定"
    else:
        dialog_title = "Browse for Folder"
        confirm_button_text = "OK"

    # 启动MBParallelReconV4.5.3应用
    import subprocess
    subprocess.Popen(["/path/to/MBParallelReconV4.5.3"])

    time.sleep(5)  # 等待应用启动

    # 获取应用窗口
    bus = pyatspi.Registry.get_instance()
    applications = bus.getApplications()
    for app in applications:
        if app.getName() == "MBParallelReconV4.5.3":
            dlg = app.getChild(0)
            break

    # 点击MB_BOLD_BrowserButton
    dlg.findChildByName("MB_BOLD_BrowserButton").click()
    time.sleep(1)

    # 选择MB_BOLD路径
    folder_dlg = bus.getApplications()[0].getChild(0)
    MB_BOLD_path = get_folder_path_for_pyatspi(MB_BOLD_path)
    folder_dlg.findChildByName(MB_BOLD_path[0]).click()
    time.sleep(1)
    folder_dlg.findChildByName(confirm_button_text).click()
    time.sleep(1)

    # 重复以上步骤选择R_BOLD和O_BOLD路径

    # 设置输出文件名
    output_edit = dlg.findChildByName("Output_FilenameEdit")
    output_edit.set_text(output_filename)
    time.sleep(1)

    # 选择输出格式
    output_combo = dlg.findChildByName("Output_FormatComboBox")
    output_combo.select("NIFTI+1")
    time.sleep(1)

    # 点击运行按钮
    run_button = dlg.findChildByName("RunButton")
    run_button.click()
    print("Script executed successfully!")

    return "Conversion completed"

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Auto convert multiband data to nifti.')
    parser.add_argument('MB_BOLD_path', type=str, help='multiband data path')
    parser.add_argument('R_BOLD_path', type=str, help='reference data path')
    parser.add_argument('O_BOLD_path', type=str, help='output data path')
    parser.add_argument('output_filename', type=str, help='output filename')

    args = parser.parse_args()
    auto_mbconvert(args.MB_BOLD_path, args.R_BOLD_path, args.O_BOLD_path, args.output_filename)