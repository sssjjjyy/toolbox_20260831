import os.path
from jinja2 import Template
import argparse
import re
import os
import base64
import pdfkit
import datetime
import nibabel as nib
import traceback
import sys
##需要安装pdfkit，argparse，下载wkhtmltopdf
##wkhtmltopdf_path = r'C:\Program Files\wkhtmltopdf\bin\wkhtmltopdf.exe'

def extract_thresh_extent_values_from_filename(filename):
    """提取文件名中的 threshold 和 extent 值"""
    match_thresh_extent = re.search(r'_thresh_(\d+\.\d+)_extent_(\d+)', filename)
    if match_thresh_extent:
        threshold = match_thresh_extent.group(1)
        extent = match_thresh_extent.group(2)
        return threshold, extent
    return None, None

def extract_scrubbed_values_from_filename(filename):
    """提取文件名中的 scrubbed 值"""
    match_scrubbed = re.search(r'_(\d+)remained_(\d+)_scrubbed_thresh_(\d+\.\d+)_cross_correlation', filename)
    if match_scrubbed:
        volume_remained = match_scrubbed.group(1)
        volume = match_scrubbed.group(2)
        ccthreshold = match_scrubbed.group(3)
        return volume, volume_remained, ccthreshold
    return None, None, None

def find_matching_files(directory):
    """查找目录中匹配的文件"""
    if not os.path.isdir(directory):
        return []
    
    matching_files = []
    files_in_dir = os.listdir(directory)
    
    for filename in files_in_dir:
        if '_thresh_' in filename and '_extent_' in filename:
            threshold, extent = extract_thresh_extent_values_from_filename(filename)
            if threshold and extent:
                matching_files.append({
                    'filename': filename,
                    'threshold': threshold,
                    'extent': extent,
                    'type': 'FLA'
                })
                
        elif '_scrubbed_thresh_' in filename and 'remained_' in filename:
            volume, volume_remained, ccthreshold = extract_scrubbed_values_from_filename(filename)
            if volume and volume_remained:
                matching_files.append({
                    'filename': filename,
                    'volume_remained': volume_remained,
                    'volume': volume,
                    'ccthreshold': ccthreshold,
                    'type': 'Scrubbed'
                })

    return matching_files

def image_to_base64(image_path):
    """将图像转换为 base64 编码"""
    if not os.path.isfile(image_path):
        return None
    
    try:
        with open(image_path, 'rb') as image_file:
            encoded = base64.b64encode(image_file.read()).decode('utf-8')
            return encoded
    except Exception as e:
        return None

def generate_report(base_path, output_dir, subject_name, hrf_type, template_file_path='longTR_template.html'):
    """生成报告"""
    try:
        result_dirs = ['default', hrf_type]
        path = base_path
        current_time = datetime.datetime.now().strftime('%Y-%m-%d-%H-%M-%S')
        
        # ========== 读取 NIfTI 文件 ==========
        nifti_path = os.path.join(base_path, f"{subject_name}.nii")
        image_info = "Resolution: Unknown, Timepoints: Unknown"
        
        if os.path.isfile(nifti_path):
            try:
                img = nib.load(nifti_path)
                data_shape = img.header.get_data_shape()
                if len(data_shape) == 4:
                    resolution = 'x'.join(map(str, data_shape[:3]))
                    timepoint = data_shape[3]
                else:
                    resolution = 'x'.join(map(str, data_shape))
                    timepoint = 1
                image_info = f"Resolution: {resolution}, Timepoints: {timepoint}"
            except Exception as e:
                pass
        
        # ========== 收集图像 ==========
        QAimages = []
        MCimages = []
        FLAimages = []
        CCimages = []
        CCMSimages = []
        
        # ========== tSNR 图像 ==========
        tsnr_file = os.path.join(path, f'{subject_name}_tSNR_thrs.bmp')
        encoded = image_to_base64(tsnr_file)
        if encoded:
            QAimages.append({
                'path': f"data:image/bmp;base64,{encoded}",
                'caption': 'Temporal SNR',
                'annotation': 'The tSNR is mostly used as a first order artifact detection tool. The higher the tSNR, the better the data quality.'
            })
        else:
            tsnr_file_png = os.path.join(path, f'{subject_name}_tSNR_thrs.png')
            encoded = image_to_base64(tsnr_file_png)
            if encoded:
                QAimages.append({
                    'path': f"data:image/png;base64,{encoded}",
                    'caption': 'Temporal SNR',
                    'annotation': 'The tSNR is mostly used as a first order artifact detection tool. The higher the tSNR, the better the data quality.'
                })
        
        # ========== Motion 图像 ==========
        motion_file = os.path.join(path, f'{subject_name}_motion.png')
        encoded = image_to_base64(motion_file)
        if encoded:
            MCimages.append({
                'path': f"data:image/png;base64,{encoded}",
                'caption': 'Motion Correction Parameter'
            })
        else:
            motion_file_bmp = os.path.join(path, f'{subject_name}_motion.bmp')
            encoded = image_to_base64(motion_file_bmp)
            if encoded:
                MCimages.append({
                    'path': f"data:image/bmp;base64,{encoded}",
                    'caption': 'Motion Correction Parameter'
                })
        
        # ========== FLA 和 CC 图像 ==========
        for result_dir in result_dirs:
            result_path = os.path.join(base_path, result_dir)
            
            if not os.path.isdir(result_path):
                continue
            
            matching_files = find_matching_files(result_path)
            
            thresholds = [file_info['threshold'] for file_info in matching_files if 'threshold' in file_info]
            extents = [file_info['extent'] for file_info in matching_files if 'extent' in file_info]
            unique_thresholds = sorted(list(set(thresholds)))
            unique_extents = sorted(list(set(extents)))
            
            # ========== FLA 图像 ==========
            for threshold in unique_thresholds:
                for extent in unique_extents:
                    # .png 文件
                    png_file = os.path.join(result_path, f'{subject_name}_thresh_{threshold}_extent_{extent}.png')
                    encoded = image_to_base64(png_file)
                    if encoded:
                        FLAimages.append({
                            'path': f"data:image/png;base64,{encoded}",
                            'caption': f"[{result_dir}] 1st level analysis (threshold={threshold}, cluster wise={extent})"
                        })
                    
                    # .bmp 文件
                    bmp_file = os.path.join(result_path, f'{subject_name}_average_percent_change_{threshold}_{extent}.bmp')
                    encoded = image_to_base64(bmp_file)
                    if encoded:
                        FLAimages.append({
                            'path': f"data:image/bmp;base64,{encoded}",
                            'caption': f"[{result_dir}] Average % change (threshold={threshold}, cluster wise={extent})"
                        })
            
            # ========== Cross-correlation 图像 ==========
            ccthresholds = [file_info['ccthreshold'] for file_info in matching_files if 'ccthreshold' in file_info]
            ccthresholds = sorted(list(set(ccthresholds)))
            
            for ccthreshold in ccthresholds:
                cc_file = os.path.join(path, f'{subject_name}_thresh_{ccthreshold}_cross_correlation.bmp')
                encoded = image_to_base64(cc_file)
                if encoded:
                    CCimages.append({
                        'path': f"data:image/bmp;base64,{encoded}",
                        'caption': f'Cross correlation - threshold {ccthreshold}'
                    })
            
            # 无阈值 cross-correlation
            cc_unthresh = os.path.join(path, f'{subject_name}_cc_unthresholded.bmp')
            encoded = image_to_base64(cc_unthresh)
            if encoded:
                CCimages.append({
                    'path': f"data:image/bmp;base64,{encoded}",
                    'caption': 'Cross correlation unthresholded'
                })
            
            # ========== Motion scrubbing 图像 ==========
            volume_remained = None
            volume = None
            for file_info in matching_files:
                if 'volume_remained' in file_info:
                    volume_remained = file_info['volume_remained']
                    volume = file_info['volume']
            
            if volume_remained and volume:
                for ccthreshold in ccthresholds:
                    scrub_file = os.path.join(path, f'{subject_name}_{volume_remained}remained_{volume}_scrubbed_thresh_{ccthreshold}_cross_correlation.bmp')
                    encoded = image_to_base64(scrub_file)
                    if encoded:
                        CCMSimages.append({
                            'path': f"data:image/bmp;base64,{encoded}",
                            'caption': f"Cross correlation after motion scrubbing (remained={volume_remained})"
                        })
            
            # 无阈值 scrubbing
            scrub_unthresh = os.path.join(path, f'{subject_name}_scrubbed_unthresholded_cc.bmp')
            encoded = image_to_base64(scrub_unthresh)
            if encoded:
                CCMSimages.append({
                    'path': f"data:image/bmp;base64,{encoded}",
                    'caption': 'Cross correlation unthresholded after motion scrubbing'
                })
        
        # ========== 准备数据 ==========
        data = {
            'title': 'LongTR Immediately Analysis Result Report',
            'subject_name': subject_name,
            'current_time': current_time,
            'Image_info': image_info,
            'QAimages': QAimages,
            'MCimages': MCimages,
            'CCimages': CCimages,
            'FLAimages': FLAimages,
            'CCMSimages': CCMSimages
        }
        
        # ========== 读取并渲染模板 ==========
        if not os.path.isfile(template_file_path):
            print(f"Error: Template file not found: {template_file_path}")
            return False
        
        with open(template_file_path, 'r', encoding='utf-8') as template_file:
            template_content = template_file.read()
        
        template = Template(template_content)
        rendered_html = template.render(data)
        
        # ========== 保存 HTML ==========
        output_directory = os.path.join(output_dir, 'Results_HTML')
        os.makedirs(output_directory, exist_ok=True)
        
        output_path = os.path.join(output_directory, f'{subject_name}_result_longTR_normal.html')
        with open(output_path, 'w', encoding='utf-8') as output_file:
            output_file.write(rendered_html)
        
        # ========== 转换为 PDF ==========
        try:
            wkhtmltopdf_path = r'C:\Program Files\wkhtmltopdf\bin\wkhtmltopdf.exe'
            
            if not os.path.isfile(wkhtmltopdf_path):
                wkhtmltopdf_path = 'wkhtmltopdf'
            
            config = pdfkit.configuration(wkhtmltopdf=wkhtmltopdf_path)
            output_pdf_path = os.path.join(output_directory, f'{subject_name}_result_longTR_normal.pdf')
            
            pdfkit.from_file(output_path, output_pdf_path, configuration=config)
            
        except Exception as e:
            pass
        
        return True
        
    except Exception as e:
        print(f"Error: {e}")
        traceback.print_exc()
        return False

if __name__ == "__main__":
    try:
        parser = argparse.ArgumentParser(description='Generate a report using Jinja2 template.')
        parser.add_argument('base_path', type=str, help='Base path for the report')
        parser.add_argument('subject_name', type=str, help='subject name for the report')
        parser.add_argument('--hrf_type', type=str, default='default', help='hrf type for the report')
        parser.add_argument('--template', type=str, default='template.html', help='Path to the HTML template file')
        parser.add_argument('--output_dir', type=str, help='Path to the output directory')
        
        args = parser.parse_args()
        generate_report(args.base_path, args.output_dir, args.subject_name, args.hrf_type, args.template)
        
    except Exception as e:
        print(f"Error: {e}")
        traceback.print_exc()