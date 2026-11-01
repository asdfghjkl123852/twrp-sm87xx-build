#!/usr/bin/env python3
"""TWRP 紫金主题 + 背景图 定制脚本（在 AOSP 源码同步后运行）。
运行目录 = $GITHUB_WORKSPACE，背景图头文件在 /tmp/ui-theme-stash/。
"""
import os
import shutil
import sys

WS = os.getcwd()
STASH = "/tmp/ui-theme-stash"
GUI2 = os.path.join(WS, "bootable", "recovery", "gui2")


def fail(msg):
    print("!!! 失败:", msg, file=sys.stderr)
    sys.exit(1)


# 1) 复制背景图头文件
img_src = os.path.join(STASH, "twrp_background_img.h")
img_dst = os.path.join(GUI2, "twrp_background_img.h")
if not os.path.exists(img_src):
    fail(f"找不到背景图头文件 {img_src}")
shutil.copy(img_src, img_dst)
print(f"已复制背景图: {img_dst} ({os.path.getsize(img_dst)} 字节)")

# 2) 补丁 gui_shell_base.cpp：加 include + 全屏背景图
sh = os.path.join(GUI2, "shell", "gui_shell_base.cpp")
txt = open(sh, encoding="utf-8").read()

old_inc = '#include "twrpminui/minui.h"\n'
if old_inc not in txt:
    fail("找不到 minui.h include 行")
txt = txt.replace(old_inc, old_inc + '#include "twrp_background_img.h"\n', 1)

old_bg = "  lv_obj_set_style_bg_opa(options.screen, LV_OPA_COVER, LV_PART_MAIN);\n"
if old_bg not in txt:
    fail("找不到 bg_opa 行")
new_bg = old_bg + (
    "  // 紫金主题：全屏背景图（已压暗，白字可读）\n"
    "  lv_obj_t* twrp_bg = lv_image_create(options.screen);\n"
    "  lv_image_set_src(twrp_bg, &twrp_background_image);\n"
    "  lv_image_set_inner_align(twrp_bg, LV_IMAGE_ALIGN_STRETCH);\n"
    "  lv_obj_set_size(twrp_bg, lv_pct(100), lv_pct(100));\n"
    "  lv_obj_move_background(twrp_bg);\n"
)
txt = txt.replace(old_bg, new_bg, 1)
open(sh, "w", encoding="utf-8").write(txt)
print("已补丁 gui_shell_base.cpp")

# 3) 补丁 ui_metrics.cpp 颜色（深色 + 浅色主题 → 紫金）
um = os.path.join(GUI2, "core", "ui_metrics.cpp")
txt = open(um, encoding="utf-8").read()
repl = {
    # 深色主题
    "0x9BC5E9": "0xB69CFF",  # accent_soft 蓝 → 浅紫
    "0x0E1B2E": "0x241538",  # accent_surface 深蓝 → 深紫
    "0xFFC46B": "0xE8C15A",  # warning 琥珀 → 金
    # 浅色主题
    "0x3482FF": "0x7C4DFF",  # accent_soft 蓝 → 紫
    "0xE2ECFF": "0xEDE7FF",  # accent_surface 浅蓝 → 浅紫
    "0xA86A00": "0xB8860B",  # warning 深琥珀 → 金
}
for a, b in repl.items():
    if a in txt:
        txt = txt.replace(a, b)
        print(f"  颜色 {a} -> {b}")
    else:
        print(f"  [跳过] 未找到 {a}")
open(um, "w", encoding="utf-8").write(txt)
print("已补丁 ui_metrics.cpp")

print("UI 定制完成")
