#!/bin/bash
###########################
#  一个内核编译脚本 by su
###########################

# 设置颜色
cinfo=$(tput setaf 39; tput setab 0)  # 正常信息颜色
cwarn=$(tput setaf 208; tput setab 0) # 警告信息颜色
cerror=$(tput setaf 196; tput setab 0) # 错误信息颜色
cno=$(tput sgr0)                    # 恢复终端默认颜色

echo -e "${cinfo}=============== 设置导出变量 ===============${cno}"

# 内核工作目录
export KERNEL_DIR=$(pwd)
# 内核 defconfig 文件
export KERNEL_DEFCONFIG=munch_defconfig
# 内核 defconfig 路径
export DEFCONFIG_PATH=${KERNEL_DIR}/arch/arm64/configs/${KERNEL_DEFCONFIG}
# 编译临时目录，避免污染根目录
export OUT=out
# anykernel3 目录
export ANYKERNEL3=${KERNEL_DIR}/AnyKernel
# 内核 zip 刷机包名称
export KERNEL_ZIP_NAME="munch_ape.zip"
# 刷机包打包完成后移动目录
export KERNEL_ZIP_EXPORT=$HOME/Kernel
# 设置 clang 绝对路径
export CLANG_PATH=$HOME/Kernel/toolchains/clang_full
export PATH=${CLANG_PATH}/bin:${PATH}
export CLANG_TRIPLE=aarch64-linux-gnu-
# arch平台，这里是arm64
export ARCH=arm64
export SUBARCH=arm64
# 设置 CC
export C='ccache clang'
export CX='ccache clang++'
# 设置ccache路径
export CCACHE_DIR=$HOME/.cache/ccache
# 其它参数
export LLVM=1
export BUILD_INITRAMFS=1


# 编译时线程指定，默认单线程，可以通过参数指定，比如4线程编译
# ./build.sh 4 
TH_COUNT=1
if [[ "$1" != "" ]]; then
    TH_COUNT="$1"
fi


### 编译参数
export DEF_ARGS="O=${OUT} \
            CC="\${C}" \
            CXX="\${CX}" \
            CROSS_COMPILE=aarch64-linux-gnu- \
            CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
            AS=llvm-as \
            AR=llvm-ar \
            NM=llvm-nm \
            OBJCOPY=llvm-objcopy \
            OBJDUMP=llvm-objdump \
            STRIP=llvm-strip \
            LD=ld.lld "
export BUILD_ARGS="-j${TH_COUNT} ${DEF_ARGS}"

# make menuconfig CC=clang CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi- LD=ld.lld LLVM=1 BUILD_INITRAMFS=1

echo -e "${cwarn}内核工作目录 ==> ${KERNEL_DIR}"
echo -e "内核 defconfig 文件 ==> ${KERNEL_DEFCONFIG}"
echo -e "编译临时目录 ==> ${KERNEL_DIR}/${OUT}"
echo -e "anykernel3 目录 ==> ${ANYKERNEL3}"
echo -e "内核 zip 刷机包名称 ==> ${KERNEL_ZIP_NAME}"
echo -e "刷机包导出目录 ==> ${KERNEL_ZIP_EXPORT}"
echo -e "clang 路径 ==> ${CLANG_PATH}"
echo -e "构建 arch/架构 ==> ${ARCH}/${SUBARCH}${cno}"
echo    # 空一行


# 检查ccache命令是否存在
if ! command -v ccache &> /dev/null; then
    echo -e "${cerror}错误: ccache 未安装，请安装后重新运行脚本.${cno}"
    exit 1
fi

# 检查ccache目录是否存在
if [ ! -d "$CCACHE_DIR" ]; then
    read -p "${cwarn}警告: ccache目录不存在。是否创建？(y/n)${cno}" -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p "$CCACHE_DIR"
        echo -e "${cwarn}ccache目录已创建。${cno}"
    else
        echo -e "${cerror}错误: ccache目录不存在，无法继续。退出脚本.${cno}"
        exit 1
    fi
fi

# 检查 clang 编译器是否存在
if [ ! -e "$CLANG_PATH" ]; then
    echo -e "${cerror}错误: clang 工具链不存在。退出脚本.${cno}"
    exit 1
fi

# 检查defconfig文件是否存在
if [ ! -e "$DEFCONFIG_PATH" ]; then
    echo -e "${cerror}错误: 内核 defconfig 文件不存在，请确保文件存在。退出脚本.${cno}"
    exit 1
fi

# 检查anykernel3目录是否存在
if [ ! -d "$ANYKERNEL3" ]; then
    read -p "${cwarn}警告: anykernel3目录不存在。是否继续运行脚本？(Enter/n)[y]: ${cno}" -r
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo -e "${cerror}退出脚本。${cno}"
        exit 1
    else
        echo -e "${cwarn} ${cno}"
    fi
fi

# 用户确认是否继续
read -p "${cwarn}是否开始编译内核？(Enter/n)[y]: ${cno}" -r
if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo -e "${cerror}退出编译。${cno}"
        exit 1
    else
        echo -e "${cwarn}\n开始编译......${cno}"
    fi


echo -e "${cinfo}=============== 编译 defconfig ===============${cno}"

# make defconfig
if [ -e out/.config ]; then
    echo "${cwarn}.config 文件已存在。${cno}"
    read -p "是否清理后编译? (y/n)[n]: " choice

    # 判断用户的选择
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        echo "${cwarn}开始清理 ...${cno}"
        (cd out && make clean && make distclean)
        rm -rf out
        echo "${cwarn}清理完成。${cno}"
        echo "${cwarn}开始编译...${cno}"
        make ${BUILD_ARGS} ${KERNEL_DEFCONFIG}
        echo "${cwarn}.config 文件编译成功。${cno}"
        read -p "是否开始编译内核? (y/n)[y]: " choice
        # 判断用户的选择
        if [[ "$choice" =~ ^[Nn]$ ]]; then
            echo "${cerror}退出编译。${cno}"
            exit 1
        else
            echo "${cwarn}开始编译内核...${cno}"
        fi
    else
        echo "${cwarn}跳过清理和编译 defconfig。${cno}"
    fi
else
    echo "${cwarn}.config 文件不存在。开始编译...${cno}"
    make ${BUILD_ARGS} ${KERNEL_DEFCONFIG}
    echo "${cwarn}.config 文件编译成功。${cno}"
        read -p "是否开始编译内核? (y/n)[y]: " choice
        # 判断用户的选择
        if [[ "$choice" =~ ^[Nn]$ ]]; then
            echo "${cerror}退出编译。${cno}"
            exit 1
        else
            echo "${cwarn}开始编译内核...${cno}"
        fi
fi


# 如果命令没有出错，继续执行，否则退出编译
if [[ "$?" -ne 0 ]]; then
    echo -e "${cerror}>>> make defconfig 错误，停止编译!${cno}"
    exit 1
fi


# 开始编译时间
starttime=`date +'%Y-%m-%d %H:%M:%S'`

echo -e "${cinfo}=============== 编译内核  ===============${cno}"
# 开始编译
make ${BUILD_ARGS}

if [[ "$?" -ne 0 ]]; then
    echo -e "${cerror}>>> 编译内核错误，停止编译!${cno}"
    exit 1
fi
echo -e "${cwarn}>>> 内核编译成功!${cno}"


# 记录编译用时
endtime=$(date +'%Y-%m-%d %H:%M:%S')
start_seconds=$(date --date="$starttime" +%s)
end_seconds=$(date --date="$endtime" +%s)
elapsed_seconds=$((end_seconds - start_seconds))
# 计算分钟和秒
minutes=$((elapsed_seconds / 60))
seconds=$((elapsed_seconds % 60))
echo "开始时间: $starttime."
echo "结束时间: $endtime."
if [ $minutes -gt 0 ]; then
    echo "本次编译用时: ${cwarn}${minutes}m ${seconds}s${cno} 。"
else
    echo "本次编译用时: ${cwarn}${seconds}s${cno} 。"
fi
echo 

# 用户确认是否生成anykernel刷机包
read -p "${cwarn}是否需要生成anykernel刷机包？(Y/n)[n]: ${cno}" -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${cerror}退出脚本。${cno}"
        exit 1
    else
        echo -e "${cwarn}\n开始生成......${cno}"
    fi

# 使用 Anykernel3 制作刷机包
echo -e "${cinfo}=============== 制作内核 Zip ==============="
if [[ -e ${ANYKERNEL3} ]]; then
    if [[ -e ${KERNEL_DIR}/${OUT}/arch/${ARCH}/boot/dtbo.img ]]; then
        if [[ -e ${KERNEL_DIR}/${OUT}/arch/${ARCH}/boot/Image ]]; then
            echo -e "${cwarn}复制内核文件 . . .${cno}"
            cp ${KERNEL_DIR}/${OUT}/arch/${ARCH}/boot/dtbo.img ${ANYKERNEL3}/
            cp ${KERNEL_DIR}/${OUT}/arch/${ARCH}/boot/Image ${ANYKERNEL3}/
            cp ${KERNEL_DIR}/${OUT}/arch/${ARCH}/boot/dtb ${ANYKERNEL3}/
            echo -e "${cwarn}进入 anykernel3 工作目录. . ."
            cd ${ANYKERNEL3}
            if [[ -e ./Image ]]; then
                zip -r ${KERNEL_ZIP_NAME} ./*
                if [[ -e ./${KERNEL_ZIP_NAME} ]]; then
                    mv ./${KERNEL_ZIP_NAME} ${KERNEL_ZIP_EXPORT}
                    echo -e "${cwarn}清理内核文件. . .${cno}"
                    [[ -e ./Image ]] && rm ./Image
                    [[ -e ./dtbo.img ]] && rm ./dtbo.img
                    [[ -e ./dtb ]] && rm ./dtb
                else
                    echo -e "${cerror}制作内核 Zip 包失败!${cno}"
                    exit 1
                fi
            else
                echo -e "${cerror}停止制作 => 未找到内核文件!${cno}"
                exit 1
            fi
        else
            echo -e "${cerror}停止制作 => 未找到 Image!${cno}"
            exit 1
        fi
    else
        echo -e "${cerror}停止制作 => 未找到 dtbo.img!${cno}"
        exit 1
    fi
else
    echo -e "${cerror}停止制作 => 未找到 anykernel3 目录!${cno}"
    exit 1
fi
exit 0
