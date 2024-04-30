### https://github.com/hooke007/MPV_lazy/wiki/3_K7sfunc
### Real-ESRGAN 放大或降噪，性能要求极高，N卡专用

import vapoursynth as vs
from vapoursynth import core
import k7sfunc as k7f

clip = video_in

############
# 用户选项 #
############

Lt_Hd = False
## <True|False> 是否对超过HD分辨率（720P）的源进行处理

Model = 5006
## <0|2|5005|5006|5007> 使用的模型

Gpu = 0
## 使用的显卡序号，0为排序一号

Gpu_T = 2
## <1|2|3> 使用的显卡线程数

St_Eng = False
## <True|False> 是否使用静态引擎（需要对不同分辨率的源各进行预处理）；动态引擎自适应不同分辨率（64²→DCI2K）

Ws_Size = 0
## <0~1024> 约束显存（MiB），静态引擎的最小值为128（动态引擎自动双倍），设为低于此数的值即为不限制

H_Max = 1440
## 整数，输出高度限制（填你的显示器高度）

Lk_Fmt = False
## <True|False> 是否锁定像素格式为yuv420p8

## 浮点，目标帧率，示例即约60fps。特殊值比如 display_fps/2 即目标为显示器刷新率的一半帧率；填 container_fps*2 即倍帧（越高的帧率增加耗能，产生更多伪影，通常是不必要的。例如对于144hz的显示器来说，最多只需要补到72fps，剩下的可让 --interpolation 帧混成补偿）
# Fps_Out = display_fps if display_fps < 120 else display_fps/2
Fps_Out = 60

## <True|False> 锁定像素格式为yuv420p8
Lk_Fmt = False

ret = k7f.FMT_CTRL(clip, h_max=1200, h_ret=True)
clip = k7f.FMT_CTRL(clip, h_max=720, fmt_pix=1 if Lk_Fmt else 0)
clip = k7f.ESRGAN_NV(clip, lt_hd=Lt_Hd, model=Model, gpu=Gpu, gpu_t=Gpu_T, st_eng=St_Eng, ws_size=Ws_Size)
clip = k7f.MVT_STD(clip, fps_in=container_fps, fps_out=Fps_Out)


clip.set_output()
