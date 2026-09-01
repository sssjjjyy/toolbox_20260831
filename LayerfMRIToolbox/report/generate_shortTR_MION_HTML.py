import os.path
from jinja2 import Template
import argparse
import re
import os
import base64
import pdfkit
import datetime
import nibabel as nib
##需要安装pdfkit，argparse，下载wkhtmltopdf


def extract_thresh_extent_values_from_filename(filename):
    # 使用正则表达式提取文件名中的数值
    match_thresh_extent = re.search(r'_average_percent_change_(\d+\.\d+)_(\d+)', filename)
    if match_thresh_extent:
        threshold = match_thresh_extent.group(1)
        extent = match_thresh_extent.group(2)
        return threshold, extent
    return None, None

def find_matching_files(directory):
    matching_files = []
    for filename in os.listdir(directory):
        if '_average_percent_change_' in filename:
            threshold, extent = extract_thresh_extent_values_from_filename(filename)
            if threshold and extent:
                matching_files.append({
                    'filename': filename,
                    'threshold': threshold,
                    'extent': extent
                })
    return matching_files

def image_to_base64(image_path):
    with open(image_path, 'rb') as image_file:
        return base64.b64encode(image_file.read()).decode('utf-8')


def generate_report(base_path, output_dir, subject_name,template_file_path='shortTR_MION_template.html'):
    path = os.path.join(base_path)
    output_dir = os.path.join(output_dir)
    current_time = datetime.datetime.now().strftime('%Y-%m-%d-%H-%M-%S')
    # img = nib.load(os.path.join(base_path, f"{subject_name}.nii"))
    # image_resolution = 'x'.join(map(str, img.header.get_data_shape()))
    img = nib.load(os.path.join(base_path, f"{subject_name}.nii"))
    data_shape = img.header.get_data_shape()
    
    if len(data_shape) == 4:
        resolution = 'x'.join(map(str, data_shape[:3]))
        timepoint = data_shape[3]
    else:
        resolution = 'x'.join(map(str, data_shape))
        timepoint = 1

    image_info = f"Resolution: {resolution}, Timepoints: {timepoint}"

    matching_files = find_matching_files(base_path)
    threshold, extent = None, None

    for file_info in matching_files:
        if 'threshold' in file_info and 'extent' in file_info:
            threshold = file_info['threshold']
            extent = file_info['extent']

    thresholds = [file_info['threshold'] for file_info in matching_files if 'threshold' in file_info]
    extents = [file_info['extent'] for file_info in matching_files if 'extent' in file_info]
    unique_thresholds = list(set(thresholds))
    unique_extents = list(set(extents))
    FLAimages = []
    for threshold in unique_thresholds:
        for extent in unique_extents:
            FLAimages.append({'path': f"data:image/png;base64,{image_to_base64(os.path.join(path, f'{subject_name}_activation_{threshold}_{extent}.bmp'))}",'caption': f"1st level analysis-activation map(AFNI,threshold={threshold},cluster wise={extent})"})
            FLAimages.append({'path': f"data:image/png;base64,{image_to_base64(os.path.join(path, f'{subject_name}_average_percent_change_{threshold}_{extent}.bmp'))}",'caption': f"1st level analysis-average percent change(AFNI,threshold={threshold},cluster wise={extent})"})
   


    data = {
        'title': 'ShortTR MION Immediately Analysis Result Report',
        'subject_name': subject_name,
        'current_time': current_time,
        'Image_info': image_info,
        'QAimages': [
            {'path': f"data:image/bmp;base64,{image_to_base64(os.path.join(path, f'{subject_name}_tSNR_thrs.bmp'))}", 'caption': 'Temporal SNR',
             'annotation': 'The tSNR is mostly used as a first order artifact detection tool. The higher the tSNR, the better the data quality.'},
        ],
        'FLAimages': FLAimages
#         'FLAimages': [
#             {'path': f"data:image/png;base64,{image_to_base64(os.path.join(path, f'{subject_name}_activation_{threshold}_{extent}.bmp'))}",'caption': f"1st level analysis-activation map(AFNI,threshold={threshold},cluster wise={extent})"},
#             {'path': f"data:image/png;base64,{image_to_base64(os.path.join(path, f'{subject_name}_average_percent_change_{threshold}_{extent}.bmp'))}",'caption': f"1st level analysis-average percent change(AFNI,threshold={threshold},cluster wise={extent})"}
#         ]
    }


    # 读取HTML模板
    try:
        with open(template_file_path, 'r') as template_file:
            template_content = template_file.read()
    except FileNotFoundError:
        print(f"Template file {template_file_path} not found.")
        return

    template = Template(template_content)
    rendered_html = template.render(data)
    output_directory = os.path.join(output_dir, 'Results_HTML')
    os.makedirs(output_directory, exist_ok=True)
    output_path = os.path.join(output_directory, f'{subject_name}_result_shortTR_MION.html')
    with open(output_path, 'w') as output_file:
        output_file.write(rendered_html)

    config = pdfkit.configuration(wkhtmltopdf=r'C:\Program Files\wkhtmltopdf\bin\wkhtmltopdf.exe')
    output_pdf_path = os.path.join(output_directory, f'{subject_name}_result_shortTR_MION.pdf')
    pdfkit.from_file(output_path, output_pdf_path, configuration=config)
    
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Generate a report using Jinja2 template.')
    parser.add_argument('base_path', type=str, help='Base path for the report')
    parser.add_argument('subject_name', type=str, help='subject name for the report')
    parser.add_argument('--template', type=str, default='template.html', help='Path to the HTML template file')
    parser.add_argument('--output_dir', type=str, help='Path to the output directory')
    
    args = parser.parse_args()
    generate_report(args.base_path, args.output_dir, args.subject_name,args.template)
