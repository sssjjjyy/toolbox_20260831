function output_img=rsfmri_smooth_2D(input_file_exclude,FWHM,voxel_size,prefix)

[~,filename,ext]  = fileparts(input_file_exclude);
EPIfilename_header=spm_vol(input_file_exclude);
input_img=spm_read_vols(EPIfilename_header);

sigma=FWHM/(2*sqrt(2*log(2))*voxel_size);
[~, ~, ImgZ, T] = size(input_img);
output_img=zeros(size(input_img));
for t = 1:T
    for z = 1:ImgZ
        output_img(:,:,z,t) = imgaussfilt(input_img(:,:,z,t), sigma,'FilterDomain','spatial');
    end
end

output_img(isnan(output_img))=0;
EPIfilename_header(1).dt = [64,0];
rp_Write4DNIfTI(output_img,EPIfilename_header(1),[prefix,filename,ext]);

end