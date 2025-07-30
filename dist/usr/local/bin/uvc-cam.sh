#!/bin/bash
set -eux

CONFIGFS="/sys/kernel/config"
GADGET="$CONFIGFS/usb_gadget/cam"
FUNCTION="$GADGET/functions/uvc.0"
mkdir -p "$FUNCTION"
echo 0x1d6b > "$GADGET/idVendor"  # linux
echo 0x0100 > "$GADGET/idProduct" # 0x100
echo 0x0100 > "$GADGET/bcdDevice" # 1.00
echo 0x0300 > "$GADGET/bcdUSB"    # useb3.o

echo 0xEF > "$GADGET/bDeviceClass"    # Miscellaneous Device Class
echo 0x02 > "$GADGET/bDeviceSubClass" # Common Class
echo 0x01 > "$GADGET/bDeviceProtocol" # Interface Association Descriptor (IAD) を使う

mkdir -p "$GADGET/strings/0x409"
echo "0123456789abcdef" > "$GADGET/strings/0x409/serialnumber"
echo "Linux"            > "$GADGET/strings/0x409/manufacturer"
echo "UVC Camera"       > "$GADGET/strings/0x409/product"

mkdir -p "$GADGET/configs/c.1/strings/0x409"
echo "UVC Camera Config" > "$GADGET/configs/c.1/strings/0x409/configuration"
echo 450                 > "$GADGET/configs/c.1/MaxPower"

mkdir -p "$GADGET/strings/0x409/iad_desc"
echo -n "Interface Association Descriptor" > "$GADGET/strings/0x409/iad_desc/s"
ln -s "$GADGET/strings/0x409/iad_desc" "$FUNCTION/iad_desc"

echo 1    > "$FUNCTION/streaming_interval"
echo 3072 > "$FUNCTION/streaming_maxpacket"
echo 4    > "$FUNCTION/streaming_maxburst"

create_frame() {
  # Example usage:
  # create_frame <width> <height> <group> <format name>
  WIDTH=$1
  HEIGHT=$2
  FORMAT=$3
  NAME=$4
  wdir="$FUNCTION/streaming/$FORMAT/$NAME/${HEIGHT}p"
  mkdir -p $wdir
  echo $WIDTH > "$wdir/wWidth"
  echo $HEIGHT > "$wdir/wHeight"
  if [ "${FORMAT}" = "mjpeg" ]; then
    echo $(( $WIDTH * $HEIGHT * 3 / 2  )) > "$wdir/dwMaxVideoFrameBufferSize"
  elif  [ "${FORMAT}" = "uncompressed" ]; then
    echo $(( $WIDTH * $HEIGHT * 2 )) > "$wdir/dwMaxVideoFrameBufferSize"
  fi
  cat <<EOF > "$wdir/dwFrameInterval"
666666
333333
166666
EOF
}

create_frame 640  480 mjpeg        mjpeg
create_frame 1280 720 mjpeg        mjpeg
create_frame 640  480 uncompressed yuyv
create_frame 1280 720 uncompressed yuyv

mkdir "$FUNCTION/streaming/color_matching/yuyv"
echo 1 > "$FUNCTION/streaming/color_matching/yuyv/bColorPrimaries"
echo 1 > "$FUNCTION/streaming/color_matching/yuyv/bTransferCharacteristics"
echo 4 > "$FUNCTION/streaming/color_matching/yuyv/bMatrixCoefficients"
ln -s "$FUNCTION/streaming/color_matching/yuyv" "$FUNCTION/streaming/uncompressed/yuyv"

mkdir "$FUNCTION/streaming/color_matching/mjpeg"
echo 1 > "$FUNCTION/streaming/color_matching/mjpeg/bColorPrimaries"
echo 1 > "$FUNCTION/streaming/color_matching/mjpeg/bTransferCharacteristics"
echo 4 > "$FUNCTION/streaming/color_matching/mjpeg/bMatrixCoefficients"
ln -s "$FUNCTION/streaming/color_matching/mjpeg" "$FUNCTION/streaming/mjpeg/mjpeg"

mkdir "$FUNCTION/streaming/header/h"
ln -s "$FUNCTION/streaming/uncompressed/yuyv" "$FUNCTION/streaming/header/h/yuyv"
ln -s "$FUNCTION/streaming/mjpeg/mjpeg"       "$FUNCTION/streaming/header/h/mjpeg"

ln -s "$FUNCTION/streaming/header/h" "$FUNCTION/streaming/class/fs/h"
ln -s "$FUNCTION/streaming/header/h" "$FUNCTION/streaming/class/hs/h"
ln -s "$FUNCTION/streaming/header/h" "$FUNCTION/streaming/class/ss/h"

mkdir -p "$FUNCTION/control/header/h"
ln -s "$FUNCTION/control/header/h" "$FUNCTION/control/class/fs"
ln -s "$FUNCTION/control/header/h" "$FUNCTION/control/class/ss"

ln -s "$GADGET/functions/uvc.0" "$GADGET/configs/c.1/uvc.0"

UDC=$(ls /sys/class/udc | head -n 1)
echo "$UDC" > "$GADGET/UDC"
