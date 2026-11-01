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

sec "CRASH REPLAY: 手动前台运行 HAL 捕获崩溃原因"
# 逐个手动运行关键 HAL，前台捕获 stderr（能直接看到 CANNOT LINK / dlopen / 符号缺失 / TEE 通信失败）
replay() {
  name="$1"; bin="$2"
  echo "--- 手动运行 $name ($bin) ---"
  [ -x "$bin" ] || { echo "  (二进制不存在或不可执行: $bin)"; return; }
  # 清空 logcat 后运行，抓崩溃输出
  logcat -c 2>/dev/null
  "$bin" > /tmp/replay.out 2>&1 &
  pid=$!
  sleep 4
  kill -9 "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
  echo "  ---- stderr/stdout ----"
  cat /tmp/replay.out 2>/dev/null
  echo "  ---- 相关 logcat ----"
  logcat -d 2>/dev/null | grep -iE 'CANNOT LINK|cannot locate symbol|dlopen|linker|namespace|Fatal signal|SIGSEGV|SIGABRT|abort|weaver|qseecom|qsee|nxp|ese|keymint|keymaster|strongbox|TEE|spu' | tail -40
}

replay "weaver_nxp"   /vendor/odm/bin/hw/android.hardware.weaver-service.nxp
replay "strongbox"    /vendor/odm/bin/hw/android.hardware.security.keymint-service.strongbox-nxp
replay "qseecomd"     /vendor/bin/qseecomd
replay "keymint-qti"  /vendor/bin/hw/android.hardware.security.keymint-service-qti
replay "gatekeeper"   /vendor/bin/hw/android.hardware.gatekeeper-service-qti

sec "SELINUX CONTEXT 检查 (keymint/gatekeeper/weaver/qseecom)"
# 这些 context "not valid (left unmapped)" 是服务起不来的重要线索
restorecon -Rv /vendor/bin/hw/ /vendor/odm/bin/hw/ /vendor/bin/qseecomd 2>&1 | grep -iE 'not valid|unmapped|keymint|gatekeeper|weaver|qseecom' | head -40

sec "KEYSTORE LOG (vold/keystore 报错)"
logcat -d 2>/dev/null | grep -Ei 'keymint|keymaster|gatekeeper|vold|fscrypt|metadata|decrypt|dm-crypt|ice|weaver|qseecom' | tail -150

sec "DMESG TAIL"
dmesg 2>/dev/null | tail -200

sec "TWRP A17 DIAG END"
echo "日志已写入 $LOG"
