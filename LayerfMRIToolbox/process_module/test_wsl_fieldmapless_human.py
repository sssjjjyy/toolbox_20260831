from nipype import config, logging
from nipype.pipeline.engine import Workflow
from sdcflows.workflows.fit.syn import init_syn_preprocessing_wf, init_syn_sdc_wf
import nibabel as nib
import os
import sys
from nipype.interfaces import io as nio

# import importlib
# # 添加本地sdcflows目录到Python路径
# sys.path.append('/mnt/c/Users/zhuyt12023/Desktop/layerfmri_mouse_immediate/sdcflows-2.10.0/sdcflows')
import sdcflows
from sdcflows.workflows.fit.syn import init_syn_preprocessing_wf, init_syn_sdc_wf

"""
Estimating the susceptibility distortions without fieldmaps.

.. testsetup::

    >>> tmpdir = getfixture('tmpdir')
    >>> tmp = tmpdir.chdir() # changing to a temporary directory
    >>> data = np.zeros((10, 10, 10, 1, 3))
    >>> data[..., 1] = 1
    >>> nb.Nifti1Image(data, None, None).to_filename(
    ...     tmpdir.join('field.nii.gz').strpath)


"""
from nipype.pipeline import engine as pe
from nipype.interfaces import utility as niu
from niworkflows.engine.workflows import LiterateWorkflow as Workflow

from sdcflows import data

DEFAULT_MEMORY_MIN_GB = 0.01
INPUT_FIELDS = (
    "epi_ref",
    "epi_mask",
    "anat_ref",
    "anat_mask",
)


def init_syn_sdc_wf(
    *,
    sloppy=False,
    debug=False,
    name="syn_sdc_wf",
    omp_nthreads=1,
):

    from packaging.version import parse as parseversion, Version
    from nipype.interfaces.ants import ImageMath
    from niworkflows.interfaces.fixes import (
        FixHeaderApplyTransforms as ApplyTransforms,
        FixHeaderRegistration as Registration,
    )
    from niworkflows.interfaces.nibabel import (
        # Binarize,
        IntensityClip,
        RegridToZooms,
    )
    from sdcflows.utils.misc import front as _pop, last as _pull
    from sdcflows.interfaces.epi import GetReadoutTime
    from sdcflows.interfaces.fmap import DisplacementsField2Fieldmap
    from sdcflows.interfaces.bspline import (
        ApplyCoeffsField,
        BSplineApprox,
        DEFAULT_LF_ZOOMS_MM,
        DEFAULT_HF_ZOOMS_MM,
        DEFAULT_ZOOMS_MM,
    )
    from sdcflows.interfaces.brainmask import BinaryDilation, Union

    ants_version = Registration().version
    if ants_version and parseversion(ants_version) < Version("2.2.0"):
        raise RuntimeError(
            f"Please upgrade ANTs to 2.2 or older ({ants_version} found)."
        )

    workflow = Workflow(name=name)
    workflow.__desc__ = f"""\
A deformation field to correct for susceptibility distortions was estimated
based on *fMRIPrep*'s *fieldmap-less* approach.
The deformation field is that resulting from co-registering the EPI reference
to the same-subject T1w-reference with its intensity inverted [@fieldmapless1;
@fieldmapless2].
Registration is performed with `antsRegistration`
(ANTs {ants_version or "-- version unknown"}), and
the process regularized by constraining deformation to be nonzero only
along the phase-encoding direction.
"""
    # 移除atlas_threshold参数和相关处理
    inputnode = pe.Node(
        niu.IdentityInterface([
            "epi_ref",
            "epi_mask",
            "anat_ref",
            "anat_mask"
        ]),
        name="inputnode"
    )

    outputnode = pe.Node(
        niu.IdentityInterface([
            "fmap",
            "fmap_ref",
            "fmap_coeff",
            "fmap_mask",
            "out_warp",
            "method",
            # "corrected_timeseries"  # 添加新的输出
        ]),
        name="outputnode"
    )

    outputnode.inputs.method = 'FLB ("fieldmap-less", SyN-based)'


    # 添加时间序列处理节点
    apply_timeseries = pe.Node(
        niu.Function(
            input_names=["in_file", "warp_file", "ref_file"],
            output_names=["out_file"],
            function=apply_warp_to_timeseries
        ),
        name="apply_timeseries"
    )


    readout_time = pe.Node(
        GetReadoutTime(),
        name="readout_time",
        run_without_submitting=True,
    )
    # 移除 atlas_msk 节点，改用 epi_mask 作为基础掩码
    mask_dil = pe.Node(BinaryDilation(), name="mask_dil")

    warp_dir = pe.Node(
        niu.Function(function=_warp_dir),
        run_without_submitting=True,
        name="warp_dir",
    )
    warp_dir.inputs.nlevels = 2


    anat_dilmsk = pe.Node(BinaryDilation(), name="anat_dilmsk")
    amask2epi = pe.Node(
        ApplyTransforms(interpolation="MultiLabel", transforms="identity"),
        name="amask2epi",
    )

    # Calculate laplacian maps
    lap_anat = pe.Node(
        ImageMath(operation="Laplacian", op2="1.5 1", copy_header=True), name="lap_anat"
    )
    lap_anat_norm = pe.Node(niu.Function(function=_norm_lap), name="lap_anat_norm")
    anat_merge = pe.Node(
        niu.Merge(2),
        name="anat_merge",
        run_without_submitting=True,
    )

    clip_epi = pe.Node(IntensityClip(p_min=35.0, p_max=99.9), name="clip_epi")
    lap_epi = pe.Node(
        ImageMath(operation="Laplacian", op2="1.5 1", copy_header=True), name="lap_epi"
    )
    lap_epi_norm = pe.Node(niu.Function(function=_norm_lap), name="lap_epi_norm")
    epi_merge = pe.Node(
        niu.Merge(2),
        name="epi_merge",
        run_without_submitting=True,
    )

    epi_umask = pe.Node(Union(), name="epi_umask")
    moving_masks = pe.Node(
        niu.Merge(3),
        name="moving_masks",
        run_without_submitting=True,
    )

    fixed_masks = pe.Node(
        niu.Merge(3),
        name="fixed_masks",
        mem_gb=DEFAULT_MEMORY_MIN_GB,
        run_without_submitting=True,
    )

    # Set a manageable size for the epi reference
    find_zooms = pe.Node(niu.Function(function=_adjust_zooms), name="find_zooms")
    zooms_epi = pe.Node(RegridToZooms(), name="zooms_epi")

    # SyN Registration Core
    syn = pe.Node(
        Registration(
            from_file=data.load(f"sd_syn{'_sloppy' * sloppy}.json")
        ),
        name="syn",
        n_procs=omp_nthreads,
    )
    syn.inputs.output_warped_image = debug
    syn.inputs.output_inverse_warped_image = debug

    if debug:
        syn.inputs.args = "--write-interval-volumes 2"

    # Extract the corresponding fieldmap in Hz
    extract_field = pe.Node(
        DisplacementsField2Fieldmap(), name="extract_field"
    )

    unwarp = pe.Node(ApplyCoeffsField(), name="unwarp")

    # Check zooms (avoid very expensive B-Splines fitting)
    zooms_field = pe.Node(
        ApplyTransforms(
            interpolation="BSpline", transforms="identity", args="-u float"
        ),
        name="zooms_field",
    )
    zooms_bmask = pe.Node(
        ApplyTransforms(
            interpolation="MultiLabel", transforms="identity", args="-u uchar"
        ),
        name="zooms_bmask",
    )

    # Regularize with B-Splines
    bs_filter = pe.Node(
        BSplineApprox(recenter=False, debug=debug, extrapolate=not debug),
        name="bs_filter",
    )
    bs_filter.interface._always_run = debug
    bs_filter.inputs.bs_spacing = (
        [DEFAULT_LF_ZOOMS_MM, DEFAULT_HF_ZOOMS_MM] if not sloppy else [DEFAULT_ZOOMS_MM]
    )

    # 更新工作流连接
    workflow.connect([
        (inputnode, readout_time, [(("epi_ref", _pop), "in_file"),
                                  (("epi_ref", _pull), "metadata")]),
        (inputnode, clip_epi, [(("epi_ref", _pop), "in_file")]),
        (inputnode, mask_dil, [("epi_mask", "in_file")]),
        (inputnode, syn, [
            ("anat_ref", "fixed_image"),  # 添加fixed_image连接
            ("anat_mask", "fixed_image_masks"),
            (("epi_ref", _get_first_element), "moving_image"),  # 使用辅助函数提取文件路径
            ("epi_mask", "moving_image_masks")
        ]),
        (inputnode, zooms_field, [(("epi_ref", _get_file_path), "reference_image")]),  # 修改这行
        (inputnode, zooms_bmask, [("anat_mask", "input_image")]),
        (inputnode, unwarp, [(("epi_ref", _get_file_path), "in_data")]),  # 添加in_data输入
        (syn, extract_field, [(("forward_transforms", _get_first_transform), "transform")]),
        (clip_epi, extract_field, [("out_file", "epi")]),
        (readout_time, extract_field, [("readout_time", "ro_time"),
                                     ("pe_direction", "pe_dir")]),
        (mask_dil, fixed_masks, [("out_file", "in1"),
                                 ("out_file", "in2")]),
        (extract_field, zooms_field, [("out_file", "input_image")]),
        (zooms_field, zooms_bmask, [("output_image", "reference_image")]),
        (zooms_field, bs_filter, [("output_image", "in_data")]),  # bs_filter 实现了平滑数据，去除噪声，以及在脑掩模之外进行B0场的外推，以减轻校正中的边界效应
        (bs_filter, unwarp, [("out_coeff", "in_coeff")]),
        (readout_time, unwarp, [("readout_time", "ro_time"),
                               ("pe_direction", "pe_dir")]),
        (zooms_bmask, outputnode, [("output_image", "fmap_mask")]),
        (bs_filter, outputnode, [("out_coeff", "fmap_coeff")]),
        (unwarp, outputnode, [("out_corrected", "fmap_ref"),
                             ("out_field", "fmap")]),
        # # 添加时间序列处理
        # (inputnode, apply_timeseries, [(("in_epis", _pop), "in_file")]),
        # (unwarp, apply_timeseries, [("out_field", "warp_file")]),
        # (inputnode, apply_timeseries, [(("epi_ref", _get_file_path), "ref_file")]),
        # (apply_timeseries, outputnode, [("out_file", "corrected_timeseries")])
   
    ])

    return workflow


def init_syn_preprocessing_wf(
    *,
    debug=False,
    name="syn_preprocessing_wf",
    omp_nthreads=1,
    auto_bold_nss=False,
    t1w_inversion=False,
):


    from niworkflows.interfaces.nibabel import (
        IntensityClip,
        ApplyMask,
        GenerateSamplingReference,
    )
    from niworkflows.interfaces.fixes import (
        FixHeaderApplyTransforms as ApplyTransforms,
        FixHeaderRegistration as Registration,
    )
    from niworkflows.workflows.epi.refmap import init_epi_reference_wf
    from sdcflows.interfaces.utils import Deoblique, DenoiseImage
    from sdcflows.interfaces.brainmask import BrainExtraction, BinaryDilation

    workflow = Workflow(name=name)

    inputnode = pe.Node(
        niu.IdentityInterface(
            fields=[
                "in_epis",
                "t_masks",
                "in_meta",
                "in_anat",
                "mask_anat"
            ]
        ),
        name="inputnode",
    )
    outputnode = pe.Node(
        niu.IdentityInterface(
            fields=[
                "epi_ref", 
                "epi_mask", 
                "anat_ref", 
                "anat_mask" 
                ]
        ),
        name="outputnode",
    )

    deob_epi = pe.Node(Deoblique(), name="deob_epi")

    anat2epi = pe.Node(
        ApplyTransforms(invert_transform_flags=[True]),
        name="anat2epi",
        n_procs=omp_nthreads,
        mem_gb=0.3,
    )
    mask2epi = pe.Node(
        ApplyTransforms(invert_transform_flags=[True], interpolation="MultiLabel"),
        name="mask2epi",
        n_procs=omp_nthreads,
        mem_gb=0.3,
    )
    mask_dtype = pe.Node(
        niu.Function(function=_set_dtype, input_names=["in_file", "dtype"]),
        name="mask_dtype",
    )
    mask_dtype.inputs.dtype = "uint8"

    epi_reference_wf = init_epi_reference_wf(
        omp_nthreads=omp_nthreads,
        auto_bold_nss=auto_bold_nss,
    )
    epi_brain = pe.Node(BrainExtraction(), name="epi_brain")
    merge_output = pe.Node(
        niu.Function(function=_merge_meta),
        name="merge_output",
        run_without_submitting=True,
    )
    mask_anat = pe.Node(ApplyMask(), name="mask_anat")
    clip_anat = pe.Node(IntensityClip(p_min=0.0, p_max=99.8), name="clip_anat")
    ref_anat = pe.Node(
        DenoiseImage(copy_header=True), name="ref_anat", n_procs=omp_nthreads
    )

    epi2anat = pe.Node(
        Registration(from_file=data.load("affine.json")),
        name="epi2anat",
        n_procs=omp_nthreads,
    )
    epi2anat.inputs.output_warped_image = debug
    epi2anat.inputs.output_inverse_warped_image = debug
    if debug:
        epi2anat.inputs.args = "--write-interval-volumes 5"

    def _remove_first_mask(in_file):
        if not isinstance(in_file, list):
            in_file = [in_file]

        in_file.insert(0, "NULL")
        return in_file

    anat_dilmsk = pe.Node(BinaryDilation(), name="anat_dilmsk")
    epi_dilmsk = pe.Node(BinaryDilation(), name="epi_dilmsk")

    sampling_ref = pe.Node(GenerateSamplingReference(), name="sampling_ref")


    # 工作流连接
    workflow.connect([
        # EPI 参考和预处理
        (inputnode, epi_reference_wf, [("in_epis", "inputnode.in_files")]),
        (inputnode, merge_output, [("in_meta", "meta_list")]),
        (inputnode, anat_dilmsk, [("mask_anat", "in_file")]),
        (inputnode, mask_anat, [("in_anat", "in_file"),
                               ("mask_anat", "in_mask")]),

        # EPI 到解剖配准
        (inputnode, mask2epi, [("mask_anat", "input_image")]),
        (epi_reference_wf, deob_epi, [("outputnode.epi_ref_file", "in_file")]),
        (deob_epi, merge_output, [("out_file", "epi_ref")]),
        (mask_anat, clip_anat, [("out_file", "in_file")]),
        (clip_anat, ref_anat, [("out_file", "input_image")]),
        (deob_epi, epi_brain, [("out_file", "in_file")]),
        (epi_brain, epi_dilmsk, [("out_mask", "in_file")]),
        
        # 配准和变换
        (ref_anat, epi2anat, [("output_image", "fixed_image")]),
        (anat_dilmsk, epi2anat, [("out_file", "fixed_image_masks")]),
        (deob_epi, epi2anat, [("out_file", "moving_image")]),
        (epi_dilmsk, epi2anat, [
            (("out_file", _remove_first_mask), "moving_image_masks")]),
        
        # 采样参考和掩码
        (deob_epi, sampling_ref, [("out_file", "fixed_image")]),
        (ref_anat, anat2epi, [("output_image", "input_image")]),
        (epi2anat, anat2epi, [("forward_transforms", "transforms")]),
        (sampling_ref, anat2epi, [("out_file", "reference_image")]),
        (epi2anat, mask2epi, [("forward_transforms", "transforms")]),
        (sampling_ref, mask2epi, [("out_file", "reference_image")]),
        
        # 输出连接
        (mask2epi, mask_dtype, [("output_image", "in_file")]),
        (anat2epi, outputnode, [("output_image", "anat_ref")]),
        (mask_dtype, outputnode, [("out", "anat_mask")]),
        (merge_output, outputnode, [("out", "epi_ref")]),
        (epi_brain, outputnode, [("out_mask", "epi_mask")]),
    ])
    # fmt:on

    if debug:
        from niworkflows.interfaces.nibabel import RegridToZooms

        regrid_anat = pe.Node(
            RegridToZooms(zooms=(2.0, 2.0, 2.0), smooth=True), name="regrid_anat"
        )
        # fmt:off
        workflow.connect([
            (inputnode, regrid_anat, [("in_anat", "in_file")]),
            (inputnode, ref_anat, [("in_anat", "input_image")]),
            (regrid_anat, sampling_ref, [("out_file", "moving_image")]),
        ])
        # fmt:on
    else:
        # fmt:off
        workflow.connect([
            (inputnode, sampling_ref, [("in_anat", "moving_image")]),
        ])
        # fmt:on

    if not auto_bold_nss:
        workflow.connect(inputnode, "t_masks", epi_reference_wf, "inputnode.t_masks")

    return workflow

# 添加辅助函数来获取文件路径
def _get_file_path(input_tuple):
    if isinstance(input_tuple, (tuple, list)):
        return input_tuple[0]  # 返回第一个元素（文件路径）
    return input_tuple

# 添加辅助函数来获取列表中的第一个路径
def _get_first_transform(transforms):
    if isinstance(transforms, (list, tuple)):
        return transforms[0]
    return transforms

# 辅助函数，提取元组中的第一个元素（文件路径）
def _get_first_element(input_tuple):
    return input_tuple[0]
def _warp_dir(fixed_image, pe_dir, nlevels=3):
    """Extract the ``restrict_deformation`` argument from metadata."""
    import numpy as np
    import nibabel as nb

    img = nb.load(fixed_image)

    if np.any(nb.affines.obliquity(img.affine) > 0.05):
        from nipype import logging

        logging.getLogger("nipype.interface").warn(
            "Running fieldmap-less registration on an oblique dataset"
        )

    vs = nb.affines.voxel_sizes(img.affine)
    order = np.around(np.abs(img.affine[:3, :3] / vs))
    retval = order @ [1 if pe_dir[0] == ax else 0.1 for ax in "ijk"]

    return nlevels * [retval.tolist()]


def _merge_meta(epi_ref, meta_list):
    """Prepare a tuple of EPI reference and metadata."""
    return (epi_ref, meta_list[0])


def _set_dtype(in_file, dtype="int16"):
    """Change the dtype of an image."""
    import numpy as np
    import nibabel as nb

    img = nb.load(in_file)
    if img.header.get_data_dtype() == np.dtype(dtype):
        return in_file

    from nipype.utils.filemanip import fname_presuffix

    out_file = fname_presuffix(in_file, suffix=f"_{dtype}")
    hdr = img.header.copy()
    hdr.set_data_dtype(dtype)
    img.__class__(img.dataobj, img.affine, hdr).to_filename(out_file)
    return out_file


def _adjust_zooms(in_anat, in_epi, z_max=2.2, z_min=1.8):
    import nibabel as nb

    anat_res = min(nb.load(in_anat).header.get_zooms()[:3])
    epi_res = min(nb.load(in_epi).header.get_zooms()[:3])
    zoom_iso = min(
        round(max(0.5 * (anat_res + epi_res), z_min), 2),
        z_max,
    )
    return tuple([zoom_iso] * 3)


def match_histogram(reference, image, ref_mask=None, img_mask=None):
    """Match the histogram of the T2-like anatomical with the EPI."""
    import os
    import numpy as np
    import nibabel as nb
    from nipype.utils.filemanip import fname_presuffix
    from skimage.exposure import match_histograms

    nii_img = nb.load(image)
    img_data = np.asanyarray(nii_img.dataobj)
    ref_data = np.asanyarray(nb.load(reference).dataobj)

    ref_mask = (
        np.ones_like(ref_data, dtype=bool)
        if ref_mask is None
        else np.asanyarray(nb.load(ref_mask).dataobj) > 0
    )

    img_mask = (
        np.ones_like(img_data, dtype=bool)
        if img_mask is None
        else np.asanyarray(nb.load(img_mask).dataobj) > 0
    )

    out_file = fname_presuffix(image, suffix="_matched", newpath=os.getcwd())
    img_data[img_mask] = match_histograms(
        img_data[img_mask],
        ref_data[ref_mask],
    )

    nii_img.__class__(
        img_data,
        nii_img.affine,
        nii_img.header,
    ).to_filename(out_file)
    return out_file


def _norm_lap(in_file):
    """Brought over from nirodents."""
    from pathlib import Path
    import numpy as np
    import nibabel as nb
    from nipype.utils.filemanip import fname_presuffix

    img = nb.load(in_file)
    data = img.get_fdata()
    data -= np.median(data)
    l_max = np.percentile(data[data > 0], 99.8)
    l_min = np.percentile(data[data < 0], 0.2)
    data[data < 0] *= -1.0 / l_min
    data[data > 0] *= 1.0 / l_max
    data = np.clip(data, a_min=-1.0, a_max=1.0)

    out_file = fname_presuffix(
        Path(in_file).name, suffix="_norm", newpath=str(Path.cwd().absolute())
    )
    hdr = img.header.copy()
    hdr.set_data_dtype("float32")
    img.__class__(data.astype("float32"), img.affine, hdr).to_filename(out_file)
    return out_file

# 添加辅助函数来应用变形场到时间序列
def apply_warp_to_timeseries(in_file, warp_file, ref_file):
    """Apply the computed warp field to all timepoints."""
    import os
    import numpy as np
    import nibabel as nb
    from nipype.interfaces.ants import ApplyTransforms
    
    # Create output directory
    out_dir = os.getcwd()
    os.makedirs(out_dir, exist_ok=True)
    
    # Load input data
    img = nb.load(in_file)
    data = img.get_fdata()
    n_timepoints = data.shape[-1]
    
    warped_data = []
    for t in range(n_timepoints):
        # Save current volume
        temp_file = os.path.join(out_dir, f"vol_{t:04d}.nii.gz")
        warped_file = os.path.join(out_dir, f"warped_{t:04d}.nii.gz")
        nb.Nifti1Image(data[..., t], img.affine).to_filename(temp_file)
        
        # Apply warp
        at = ApplyTransforms()
        at.inputs.dimension = 3
        at.inputs.input_image = temp_file
        at.inputs.reference_image = ref_file
        at.inputs.transforms = [warp_file]
        at.inputs.output_image = warped_file
        at.inputs.interpolation = 'Linear'
        at.run()
        
        # Verify file exists
        if os.path.exists(warped_file):
            warped_data.append(nb.load(warped_file).get_fdata())
            os.remove(temp_file)
            os.remove(warped_file)
        else:
            raise FileNotFoundError(f"Failed to create warped file: {warped_file}")
    
    # Merge timepoints
    warped_data = np.stack(warped_data, axis=-1)
    out_file = os.path.join(out_dir, "corrected_timeseries.nii.gz")
    nb.Nifti1Image(warped_data, img.affine).to_filename(out_file)
    
    return out_file


def test_fieldmapless_correction(
    bids_root,
    subject_id,
    output_dir,
    task_id="rest"
):
    """运行fieldmap-less校正测试"""
    
    # 配置 Nipype
    config.set('execution', 'stop_on_first_crash', 'true')
    config.set('execution', 'remove_unnecessary_outputs', 'false')
    config.set('execution', 'keep_inputs', 'true')
    config.set('logging', 'workflow_level', 'DEBUG')
    
    # 设置输入路径
    func_file = f"{bids_root}/sub-{subject_id}/func/sub-{subject_id}_task-{task_id}_bold.nii.gz"
    anat_file = f"{bids_root}/sub-{subject_id}/anat/sub-{subject_id}_T1w.nii.gz"
    mask_file = f"{bids_root}/sub-{subject_id}/anat/sub-{subject_id}_T1w_brainmask.nii.gz"
    
    metadata = {
    "PhaseEncodingDirection": "j-",
    "TotalReadoutTime": 0.023814  # 单位是秒
}
    
    # 创建工作流
    workflow = Workflow(name=f"fieldmapless_sub-{subject_id}")
    workflow.base_dir = output_dir
    
    # 1. 预处理工作流
    preproc_wf = init_syn_preprocessing_wf(
        debug=False, 
        name='syn_preprocessing_wf', 
        omp_nthreads=1, 
        auto_bold_nss=False, 
        t1w_inversion=False
    )
    
    # 设置预处理输入
    preproc_wf.inputs.inputnode.in_epis = [func_file]
    preproc_wf.inputs.inputnode.in_meta = [metadata]
    preproc_wf.inputs.inputnode.in_anat = anat_file
    preproc_wf.inputs.inputnode.mask_anat = mask_file
    
    # Create a mask for each timepoint (630 timepoints)
    func_img = nib.load(func_file)
    n_timepoints = func_img.shape[-1]
    preproc_wf.inputs.inputnode.t_masks = [True] * n_timepoints  # Create a mask for each timepoint

    # 2. SyN配准工作流
    syn_wf = init_syn_sdc_wf(
        # atlas_threshold=0, 
        sloppy=False, 
        debug=False, 
        name='syn_sdc_wf', 
        omp_nthreads=1
    )

    datasink = pe.Node(nio.DataSink(base_directory=output_dir), name='datasink')

    # 连接工作流
    workflow.connect([
        (preproc_wf, syn_wf, [
            ('outputnode.epi_ref', 'inputnode.epi_ref'),
            ('outputnode.epi_mask', 'inputnode.epi_mask'),
            ('outputnode.anat_ref', 'inputnode.anat_ref'),
            ('outputnode.anat_mask', 'inputnode.anat_mask'),
        ]),
        # (syn_wf, datasink, [('outputnode.corrected_timeseries', 'corrected_bold')])
    ])

    
    # 运行工作流
    workflow.run()

if __name__ == "__main__":
    
    # 设置日志级别
    logging.getLogger('nipype.workflow').setLevel('DEBUG')
    logging.getLogger('nipype.interface').setLevel('DEBUG')# 运行基本测试
    
    print("\nRunning fieldmapless correction test...")
    # 运行测试
    test_fieldmapless_correction(
        bids_root='/mnt/c/Users/zhuyt12023/Desktop/layerfmri_mouse_immediate/sdcflows-2.10.0/test_data',
        subject_id="01",
        output_dir='/mnt/c/Users/zhuyt12023/Desktop/layerfmri_mouse_immediate/sdcflows-2.10.0/test_data/derivatives'
    )
    # try:
    #     test_fieldmapless_correction(bids_root, subject_id, output_dir)
    #     print("Fieldmapless correction test passed!")
    # except Exception as e:
    #     print(f"Fieldmapless correction test failed: {str(e)}")


# ##1. 确保 WSL 中安装了 Python 和相关库
# 在 WSL 中，您需要安装与代码依赖项相符的 Python 环境。建议使用 Conda 或 venv 创建虚拟环境，并安装所需库。

# 安装 Python 和虚拟环境
# sudo apt update
# sudo apt install python3 python3-pip python3-venv

# python3 -m venv env
# source env/bin/activate
# pip install nipype nibabel sdcflows

# 6. 检查文件系统权限
# 确保输入和输出目录的权限在 WSL 中是可写的。
# sudo chmod -R 777 /mnt/c/Users/zhuyt12023/Desktop/layerfmri_mouse_immediate
# 7. 验证运行环境
# 在运行脚本之前测试以下命令：3dvolreg -help
# python3 /mnt/c/Users/zhuyt12023/Desktop/layerfmri_mouse_immediate/sdcflows-2.10.0/sdcflows/test_wsl.py

# export FREESURFER_HOME=/freesurfer/freesurfer
# source $FREESURFER_HOME/SetUpFreeSurfer.sh
# source ~/.bashrc



