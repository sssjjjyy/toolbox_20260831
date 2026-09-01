import SimpleITK as sitk
import argparse

def apply_transform_to_4D(input_filename, reference_filename, transform_filename, output_filename):
    # 读取输入的4D fMRI数据、参考结构图像和变换矩阵
    input_image = sitk.ReadImage(input_filename)
    reference_image = sitk.ReadImage(reference_filename)
    transform = sitk.ReadTransform(transform_filename)

    # 获取时间点数
    t = input_image.GetSize()[-1]
    registered_volumes = []

    # 使用参考图像的属性创建一个新的空图像作为Resample的输出模板
    output_image_template = sitk.Image(reference_image.GetSize(), input_image.GetPixelID())
    output_image_template.SetOrigin(reference_image.GetOrigin())
    output_image_template.SetSpacing(reference_image.GetSpacing())
    output_image_template.SetDirection(reference_image.GetDirection())

    # 对每个时间点的体积应用变换并调整分辨率
    for volume_index in range(t):
        # 获取当前体积
        current_volume = sitk.Extract(input_image, [input_image.GetSize()[0], input_image.GetSize()[1], input_image.GetSize()[2], 0], [0, 0, 0, volume_index])

        # 应用变换并调整分辨率
        registered_volume = sitk.Resample(current_volume, output_image_template, transform, sitk.sitkLinear, 0.0)
        registered_volumes.append(registered_volume)

    # 将所有已注册的体积合并为一个4D图像
    combined_4D_image = sitk.JoinSeries(registered_volumes)

    # 检查是否需要显式类型转换
    if combined_4D_image.GetPixelID() != input_image.GetPixelID():
        combined_4D_image = sitk.Cast(combined_4D_image, input_image.GetPixelID())

    # 保存4D结果
    sitk.WriteImage(combined_4D_image, output_filename)

def main():
    parser = argparse.ArgumentParser(description="Apply transformation to 4D fMRI data.")
    parser.add_argument("input_filename", type=str, help="The input 4D fMRI data filename.")
    parser.add_argument("reference_filename", type=str, help="The reference image filename.")
    parser.add_argument("transform_filename", type=str, help="The transformation file.")
    parser.add_argument("output_filename", type=str, help="The output filename for the transformed 4D data.")

    args = parser.parse_args()

    apply_transform_to_4D(args.input_filename, args.reference_filename, args.transform_filename, args.output_filename)

if __name__ == "__main__":
    main()
