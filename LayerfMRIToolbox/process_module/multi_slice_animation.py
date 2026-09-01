from nilearn import plotting
import numpy as np
from matplotlib import pyplot as plt
from matplotlib.animation import FuncAnimation
import nibabel as nib
from nilearn import image
from nilearn import datasets

def create_multi_slice_animation(t1_img, func_img, 
                               z_cuts=[-20, -10, 0, 10, 20, 30],
                               output_gif='multi_slice_registration.gif',
                               fps=2, duration=4):
    """
    创建多切片的结构相和功能相配准动画
    
    参数:
    t1_img: str, T1结构像的路径
    func_img: str, 功能像的路径
    z_cuts: list, 切片位置列表
    output_gif: str, 输出GIF文件路径
    fps: int, 每秒帧数
    duration: int, 动画持续时间(秒)
    """
    # 计算布局
    n_slices = len(z_cuts)
    n_cols = 3  # 每行显示的切片数
    n_rows = int(np.ceil(n_slices / n_cols))
    
    # 创建图像
    fig = plt.figure(figsize=(5*n_cols, 5*n_rows))
    
    # 计算总帧数和alpha值
    n_frames = fps * duration
    alpha_values = np.linspace(0, 1, n_frames)
    
    def update(frame):
        plt.clf()  # 清除当前帧
        
        # 遍历每个切片位置
        for idx, z_coord in enumerate(z_cuts):
            ax = plt.subplot(n_rows, n_cols, idx + 1)
            
            # 绘制结构像
            display = plotting.plot_anat(
                t1_img,
                display_mode='z',
                cut_coords=[z_coord],
                axes=ax,
                title=f'z = {z_coord}mm'
            )
            
            # 叠加功能像
            display.add_overlay(
                func_img,
                alpha=alpha_values[frame],
                cmap='hot'
            )
        
        plt.suptitle(f'Registration Visualization (alpha={alpha_values[frame]:.2f})',
                    y=0.95, fontsize=16)
        plt.tight_layout()
        
    # 创建动画
    anim = FuncAnimation(
        fig, 
        update, 
        frames=n_frames,
        interval=1000/fps,
        blit=False
    )
    
    # 保存为GIF
    anim.save(output_gif, writer='pillow')
    plt.close()

# 三平面版本的动画
def create_three_plane_animation(t1_img, func_img,
                               x_cuts=[-10, 0, 10],
                               y_cuts=[-10, 0, 10],
                               z_cuts=[-10, 0, 10],
                               output_gif='three_plane_animation.gif',
                               fps=2, duration=4):
    """
    创建三个平面的多切片配准动画
    
    参数:
    t1_img: str, T1结构像的路径
    func_img: str, 功能像的路径
    x_cuts: list, x轴切片位置
    y_cuts: list, y轴切片位置
    z_cuts: list, z轴切片位置
    output_gif: str, 输出GIF文件路径
    fps: int, 每秒帧数
    duration: int, 动画持续时间(秒)
    """
    # 创建图像
    n_rows = 3  # 三个方向
    n_cols = max(len(x_cuts), len(y_cuts), len(z_cuts))
    fig = plt.figure(figsize=(5*n_cols, 5*n_rows))
    
    # 计算总帧数和alpha值
    n_frames = fps * duration
    alpha_values = np.linspace(0, 1, n_frames)
    
    def update(frame):
        plt.clf()
        
        # 绘制矢状面切片 (x轴)
        for idx, x in enumerate(x_cuts):
            ax = plt.subplot(n_rows, n_cols, idx + 1)
            display = plotting.plot_anat(
                t1_img,
                display_mode='x',
                cut_coords=[x],
                axes=ax,
                title=f'x = {x}mm'
            )
            display.add_overlay(func_img, alpha=alpha_values[frame], cmap='hot')
        
        # 绘制冠状面切片 (y轴)
        for idx, y in enumerate(y_cuts):
            ax = plt.subplot(n_rows, n_cols, n_cols + idx + 1)
            display = plotting.plot_anat(
                t1_img,
                display_mode='y',
                cut_coords=[y],
                axes=ax,
                title=f'y = {y}mm'
            )
            display.add_overlay(func_img, alpha=alpha_values[frame], cmap='hot')
        
        # 绘制水平面切片 (z轴)
        for idx, z in enumerate(z_cuts):
            ax = plt.subplot(n_rows, n_cols, 2*n_cols + idx + 1)
            display = plotting.plot_anat(
                t1_img,
                display_mode='z',
                cut_coords=[z],
                axes=ax,
                title=f'z = {z}mm'
            )
            display.add_overlay(func_img, alpha=alpha_values[frame], cmap='hot')
        
        plt.suptitle(f'Registration Visualization (alpha={alpha_values[frame]:.2f})',
                    y=0.95, fontsize=16)
        plt.tight_layout()
    
    # 创建动画
    anim = FuncAnimation(
        fig, 
        update, 
        frames=n_frames,
        interval=1000/fps,
        blit=False
    )
    
    # 保存为GIF
    anim.save(output_gif, writer='pillow')
    plt.close()

if __name__ == "__main__":
    import argparse
    
    # 创建参数解析器
    parser = argparse.ArgumentParser(description='Create registration animation')
    parser.add_argument('--t1_img', type=str, required=True,
                        help='Path to T1 structural image')
    parser.add_argument('--func_img', type=str, required=True,
                        help='Path to functional image')
    
    # 解析参数
    args = parser.parse_args()
    
    # 创建单平面多切片动画
    create_multi_slice_animation(
        args.t1_img,
        args.func_img,
        z_cuts=[-20, -10, 0, 10, 20, 30],
        output_gif='multi_slice_registration.gif',
        fps=4,
        duration=3
    )
    
    # 创建三平面多切片动画
    create_three_plane_animation(
        args.t1_img,
        args.func_img,
        x_cuts=[-20, 0, 20],
        y_cuts=[-20, 0, 20],
        z_cuts=[-20, 0, 20],
        output_gif='three_plane_animation.gif',
        fps=4,
        duration=3
    )
