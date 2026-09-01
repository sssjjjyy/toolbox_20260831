# pip install pywin32
# pip install pywinauto
from pywinauto.application import Application
import time
import locale
import win32api
import argparse


def get_drive_label(drive_letter):
    try:
        volume_info = win32api.GetVolumeInformation(f"{drive_letter}:\\")
        return volume_info[0]  # The volume label is the first element in the tuple
    except Exception as e:
        return str(e)

def get_folder_path_for_pywinauto(input_path):
    default_locale = locale.getdefaultlocale()
    drive_letter = input_path[0]  # Extract the drive letter
    drive_name = get_drive_label(drive_letter)
    drive = f"{drive_name}({drive_letter}:)"

    if default_locale[0] == 'zh_CN':
        users = u'用户'
        desktop = u'桌面'
        this_computer = u'此电脑'
    else:
        users = 'Users'
        desktop = 'Desktop'
        this_computer = 'This PC'
    path_parts = input_path.split('\\')
    if 'Desktop' in path_parts:
        if default_locale[0] == 'zh_CN':
            path_parts[path_parts.index('Desktop')] = u'桌面'
            path_parts[path_parts.index('Users')] = u'用户'
    pywinauto_path = [desktop, this_computer, drive] + path_parts[1:]
    pywinauto_path_formatted = [u'{}'.format(part) for part in pywinauto_path]
    return pywinauto_path_formatted

def auto_mbconvert(MB_BOLD_path, R_BOLD_path, O_BOLD_path, output_filename):
    default_locale = locale.getdefaultlocale()
    if default_locale[0] == 'zh_CN':
        dialog_title = "浏览文件夹"
        confirm_button_text = "确定"
    else:
        dialog_title = "Browse for Folder"
        confirm_button_text = "OK"

    app = Application().start(r"C:\Users\zhuyt12023\Desktop\layerfmri_ui\layerfmri_code\utils\MBParallelReconV4.5.3.exe")
    dlg = app.window(title="MBParallelReconV4.5.3")

    ##这一行就可以知道这个窗口有哪些控件
    #dlg.print_control_identifiers()

    dlg.MB_BOLD_BrowserButton.click()
    time.sleep(1)
    folder_dlg = app.window(title=dialog_title)
    MB_BOLD_path = r"{}".format(MB_BOLD_path)
    MB_BOLD = get_folder_path_for_pywinauto(MB_BOLD_path)
    folder_dlg.TreeView.get_item(MB_BOLD).click()
    time.sleep(1)
    folder_dlg[confirm_button_text].click()
    time.sleep(1)

    dlg.Reference_BrowserButton.click()
    time.sleep(1)
    folder_dlg = app.window(title=dialog_title)
    R_BOLD_path = r"{}".format(R_BOLD_path)
    R_BOLD = get_folder_path_for_pywinauto(R_BOLD_path)
    folder_dlg.TreeView.get_item(R_BOLD).click()
    time.sleep(1)
    folder_dlg[confirm_button_text].click()
    time.sleep(1)

    dlg.Output_BrowserButton.click()
    time.sleep(1)
    folder_dlg = app.window(title=dialog_title)
    O_BOLD_path = r"{}".format(O_BOLD_path)
    O_BOLD = get_folder_path_for_pywinauto(O_BOLD_path)
    folder_dlg.TreeView.get_item(O_BOLD).click()
    time.sleep(1)
    folder_dlg[confirm_button_text].click()
    time.sleep(1)


    dlg.Output_FilenameEdit.set_text(output_filename)
    dlg.Output_FormatComboBox.select("NIFTI+1")

    if dlg.B0_Drifting_CorrectionCheckBox.get_check_state():
        dlg.B0_Drifting_CorrectionCheckBox.click()

    dlg.RunButton.click()
    print("Script executed successfully!")
    
    return "Conversion completed"

# MB_BOLD_path=r"C:\Users\zhuyt12023\Desktop\layerfmri_mouse_immediate\b2n_test\raw\20240721_100023_LTN_20240721_3_1_341\9"
# R_BOLD_path=r"C:\Users\zhuyt12023\Desktop\layerfmri_mouse_immediate\b2n_test\raw\20240721_100023_LTN_20240721_3_1_341\8"
# O_BOLD_path=r"C:\Users\zhuyt12023\Desktop\layerfmri_mouse_immediate\b2n_test\raw\20240721_100023_LTN_20240721_3_1_341\9\pdata\1\dicom"
# output_filename = "3_9"
# auto_mbconvert(MB_BOLD_path, R_BOLD_path, O_BOLD_path, output_filename)
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Auto convert multiband data to nifti.')
    parser.add_argument('MB_BOLD_path', type=str, help='multiband data path')
    parser.add_argument('R_BOLD_path', type=str, help='reference data path')
    parser.add_argument('O_BOLD_path', type=str, help='output data path')
    parser.add_argument('output_filename', type=str, help='output filename')

    args = parser.parse_args()
    auto_mbconvert(args.MB_BOLD_path, args.R_BOLD_path, args.O_BOLD_path, args.output_filename)