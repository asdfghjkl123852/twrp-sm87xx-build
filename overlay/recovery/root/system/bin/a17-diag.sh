#!/system/bin/sh
# =============================================================================
#  Android 17 (ColorOS 17) 适配诊断脚本
#  由 init.recovery.qcom.rc 在内核模块加载完成后自动执行（oneshot）
#  输出: /tmp/a17-diag.log
#  取回: 在 TWRP 里启用 adb 后执行  adb pull /tmp/a17-diag.log
#  用途: 判断 A17 固件上 解密失败/触摸失效/挂载异常 的真实原因
# =============================================================================

LOG=/tmp/a17-diag.log
: > "$LOG"
exec >>"$LOG" 2>&1

sec() { echo; echo "===== $* ====="; }

sec "TWRP A17 DIAG START"
echo "date      : $(date 2>/dev/null)"
echo "kernel    : $(cat /proc/version 2>/dev/null)"
echo "cmdline   : $(cat /proc/cmdline 2>/dev/null)"

sec "PROPS (build / product / boot / vendor / twrp)"
getprop 2>/dev/null | grep -E 'ro\.(build\.version|product\.|boot\.|vendor\.|twrp\.|oplus|system\.)|init\.svc\.|twrp\.' | sort

sec "BLOCK DEVICES (by-name)"
ls -l /dev/block/by-name/ 2>/dev/null

sec "BLKID (加密相关分区)"
for p in metadata userdata super persist; do
  if [ -e "/dev/block/by-name/$p" ]; then
    printf '%-10s ' "$p"
    blkid "/dev/block/by-name/$p" 2>/dev/null || echo "(blkid unavailable)"
  fi
done

sec "PARTITION SIZES (userdata / metadata)"
for p in userdata metadata; do
  if [ -e "/dev/block/by-name/$p" ]; then
    printf '%-10s ' "$p"
    blockdev --getsize64 "/dev/block/by-name/$p" 2>/dev/null || echo "(blockdev unavailable)"
  fi
done

sec "MOUNTS"
cat /proc/mounts 2>/dev/null

sec "RECOVERY FSTAB"
cat /etc/recovery.fstab 2>/dev/null
echo "--- twrp.flags ---"
cat /etc/twrp.flags 2>/dev/null

sec "HAL SERVICES (init state)"
getprop 2>/dev/null | grep '^init\.svc\.' | sort

sec "KEYMINT / GATEKEEPER / WEAVER / STRONGBOX BINARIES"
ls -l /vendor/bin/hw/ 2>/dev/null | grep -Ei 'keymint|gatekeeper|weaver|secure_element|strongbox|boot'
echo "--- odm ---"
ls -l /vendor/odm/bin/hw/ 2>/dev/null | grep -Ei 'keymint|weaver|strongbox|touch|vibrator'

sec "VINTF MANIFEST (加密相关片段)"
for f in /vendor/etc/vintf/manifest.xml \
         /vendor/etc/vintf/manifest/android.hardware.security.keymint-service-qti.xml \
         /vendor/odm/etc/vintf/manifest/manifest_oplus_keymint_aidl.xml \
         /vendor/odm/etc/vintf/manifest/manifest_oplus_weaver_aidl.xml; do
  [ -f "$f" ] || continue
  echo "--- $f ---"
  grep -Ei 'name=|version|keymint|weaver|gatekeeper|strongbox|hal' "$f" 2>/dev/null | head -40
done

sec "FIRMWARE MOUNT (TA 文件所在)"
ls -l /vendor/firmware_mnt/ 2>/dev/null | head -30
ls -l /vendor/firmware_mnt/image/ 2>/dev/null | head -20

sec "VENDOR_DLKM MODULES (触摸/充电等)"
ls -l /vendor_dlkm/lib/modules/ 2>/dev/null | head -60
lsmod 2>/dev/null | head -40

sec "KEYSTORE LOG (vold/keystore 报错)"
logcat -d -t 400 2>/dev/null | grep -Ei 'keymint|keymaster|gatekeeper|vold|fscrypt|metadata|decrypt|dm-crypt|ice' | tail -120

sec "DMESG TAIL"
dmesg 2>/dev/null | tail -200

sec "TWRP A17 DIAG END"
echo "日志已写入 $LOG"
