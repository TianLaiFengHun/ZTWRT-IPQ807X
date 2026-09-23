#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

#预置HomeProxy数据
if [ -d *"homeproxy"* ]; then
	echo " "

	HP_RULE="surge"
	HP_PATH="homeproxy/root/etc/homeproxy"

	rm -rf ./$HP_PATH/resources/*

	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
	mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/

	cd .. && rm -rf ./$HP_RULE/

	cd $PKG_PATH && echo "homeproxy date has been updated!"
fi

#修改argon主题字体和颜色
if [ -d *"luci-theme-argon"* ]; then
	echo " " && cd ./luci-theme-argon/

	sed -i "s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/" ./luci-app-argon-config/root/etc/config/argon

	cd $PKG_PATH && echo "theme-argon has been fixed!"
fi

#修改aurora菜单式样
if [ -d *"luci-app-aurora-config"* ]; then
	echo " " && cd ./luci-app-aurora-config/

	sed -i "s/nav_submenu_type '.*'/nav_submenu_type 'boxed-dropdown'/g" $(find ./root/usr/share/aurora/ -type f -name "*.template")

	cd $PKG_PATH && echo "theme-aurora has been fixed!"
fi

#修改mini-diskmanager菜单位置
if [ -d *"luci-app-mini-diskmanager"* ]; then
	echo " " && cd ./luci-app-mini-diskmanager/

	sed -i "s/services/system/g" ./luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json

	cd $PKG_PATH && echo "mini-diskmanager has been fixed!"
fi

#修改qca-nss-drv启动顺序
NSS_DRV="../feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init"
if [ -f "$NSS_DRV" ]; then
	echo " "

	sed -i 's/START=.*/START=85/g' $NSS_DRV

	cd $PKG_PATH && echo "qca-nss-drv has been fixed!"
fi

#修改qca-nss-pbuf启动顺序
NSS_PBUF="./kernel/mac80211/files/qca-nss-pbuf.init"
if [ -f "$NSS_PBUF" ]; then
	echo " "

	sed -i 's/START=.*/START=86/g' $NSS_PBUF

	cd $PKG_PATH && echo "qca-nss-pbuf has been fixed!"
fi

#修复TailScale配置文件冲突
#按 asvow/luci-app-tailscale 官方要求：
#删除 openwrt/packages 自带 tailscale Makefile 中安装
#  $(INSTALL_BIN) ./files//tailscale.init $(1)/etc/init.d/tailscale
#  $(INSTALL_DATA) ./files//tailscale.conf $(1)/etc/config/tailscale
#这两行，由 luci-app-tailscale 统一提供 /etc/init.d/tailscale 与
#/etc/config/tailscale，避免 package/install 阶段文件归属冲突
#(ERROR: trying to overwrite ... owned by tailscale-xxx)。
#注意：不能再用 sed -i '/\/files/d'（会误删其它含 /files 的行）。
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
	echo " "

	sed -i '/\/etc\/init\.d\/tailscale/d;/\/etc\/config\/tailscale/d' $TS_FILE

	cd $PKG_PATH && echo "tailscale has been fixed!"
fi

#修复Rust编译失败
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
if [ -f "$RUST_FILE" ]; then
	echo " "

	sed -i 's/ci-llvm=true/ci-llvm=false/g' $RUST_FILE

	cd $PKG_PATH && echo "rust has been fixed!"
fi

# 修复 quickstart（避免菜单异常 / 依赖问题）
QS_DIR=$(find ./ ../feeds/ -maxdepth 3 -type d -iname "*luci-app-quickstart*" 2>/dev/null | head -n 1)
if [ -n "$QS_DIR" ]; then
    echo " "
    echo "Fix quickstart..."

    # 有些版本菜单位置不对
    MENU_FILE=$(find "$QS_DIR" -type f -name "*.json" 2>/dev/null)
    if [ -n "$MENU_FILE" ]; then
        sed -i 's/"services"/"system"/g' "$MENU_FILE"
    fi

    echo "quickstart has been fixed!"
fi


# 修复 diskman（ntfs3 替换 + 依赖清理）
DM_DIR=$(find ./ ../feeds/ -maxdepth 3 -type d -iname "*luci-app-diskman*" 2>/dev/null | head -n 1)
if [ -n "$DM_DIR" ]; then
    echo " "
    echo "Fix diskman..."

    MAKEFILE="$DM_DIR/Makefile"
    if [ -f "$MAKEFILE" ]; then
        sed -i 's/fs-ntfs /fs-ntfs3 /g' "$MAKEFILE"
        sed -i '/ntfs-3g-utils/d' "$MAKEFILE"
    fi

    echo "diskman has been fixed!"
fi


# 修复 istorex（菜单 + 兼容）
IS_DIR=$(find ./ ../feeds/ -maxdepth 3 -type d -iname "*istore*" 2>/dev/null | head -n 1)
if [ -n "$IS_DIR" ]; then
    echo " "
    echo "Fix istorex..."

    # 防止和旧 istore 冲突
    rm -rf ../feeds/luci/applications/luci-app-store 2>/dev/null

    # 菜单位置统一
    MENU_FILE=$(find "$IS_DIR" -type f -name "*.json" 2>/dev/null)
    if [ -n "$MENU_FILE" ]; then
        sed -i 's/"nas"/"services"/g' "$MENU_FILE"
    fi

    echo "istorex has been fixed!"
fi

# 修改 UPnP IGD 菜单位置到"网络"
UPNP_MENU=$(find ./ ../feeds/ -path "*/luci-app-upnp/root/usr/share/luci/menu.d/luci-app-upnp.json" 2>/dev/null | head -n 1)
if [ -n "$UPNP_MENU" ]; then
    sed -i 's/"admin\/services\/upnp"/"admin\/network\/upnp"/g' "$UPNP_MENU"
    echo "upnp menu moved to network"
fi

# 删除系统菜单下的"插件"项
SYS_MENU=$(find ./ ../feeds/ -path "*/luci-mod-system/root/usr/share/luci/menu.d/luci-mod-system.json" 2>/dev/null | head -n 1)
if [ -n "$SYS_MENU" ]; then
    sed -i '/"admin\/system\/plugins": {/,/^\t},$/d' "$SYS_MENU"
    echo "system plugins menu removed"
fi

# 修改 Tailscale 菜单位置到"服务"
# TS_MENU=$(find ./ ../feeds/ -path "*/luci-app-tailscale/root/usr/share/luci/menu.d/luci-app-tailscale.json" 2>/dev/null | head -n 1)
# if [ -n "$TS_MENU" ]; then
#     sed -i 's/"admin\/vpn\/tailscale"/"admin\/services\/tailscale"/g' "$TS_MENU"
#     sed -i 's/admin\/vpn\/tailscale/admin\/services\/tailscale/g' $(find ./ -path "*/luci-app-tailscale/luasrc/controller/*.lua" 2>/dev/null)
#     echo "tailscale menu moved to services"
# fi

# 修复 luci-light 缺少 luci-theme-alpha 依赖
LIGHT_MAKE=$(find ../feeds/ -path "*/luci-light/Makefile" 2>/dev/null | head -n 1)
if [ -n "$LIGHT_MAKE" ]; then
    sed -i 's/+luci-theme-alpha //g' "$LIGHT_MAKE"
    echo "luci-light fixed: removed luci-theme-alpha dep"
fi

# 修改 ddns-go 菜单位置到"VPN/组网"
DDNS_MENU=$(find ./ ../feeds/ -path "*/luci-app-ddns-go/root/usr/share/luci/menu.d/*.json" 2>/dev/null | head -n 1)
if [ -n "$DDNS_MENU" ]; then
    sed -i 's#"admin/services/ddns-go"#"admin/vpn/ddns-go"#g; s#"admin/nas/ddns-go"#"admin/vpn/ddns-go"#g; s#"admin/services"#"admin/vpn"#g; s#"admin/nas"#"admin/vpn"#g' "$DDNS_MENU"
    echo "ddns-go menu moved to vpn"
fi

# 修改 easytier 菜单位置到"VPN/组网"（若默认不在 vpn）
ET_MENU=$(find ./ ../feeds/ -path "*/luci-app-easytier/root/usr/share/luci/menu.d/*.json" 2>/dev/null | head -n 1)
if [ -n "$ET_MENU" ]; then
    sed -i 's#"admin/services/easytier"#"admin/vpn/easytier"#g; s#"admin/nas/easytier"#"admin/vpn/easytier"#g; s#"admin/services"#"admin/vpn"#g; s#"admin/nas"#"admin/vpn"#g' "$ET_MENU"
    echo "easytier menu moved to vpn"
fi

# 修改 VPN 菜单显示名为"组网"（内含 ddns-go / easytier / tailscale）
VP_BASE=$(find ./ ../feeds/ -path "*/luci-base/root/usr/share/luci/menu.d/luci-base.json" 2>/dev/null | head -n 1)
if [ -n "$VP_BASE" ]; then
    sed -i '/"admin\/vpn": {/,/^[[:space:]]*},$/ s/"title": "VPN"/"title": "组网"/' "$VP_BASE"
    echo "vpn menu renamed to 组网"
fi

# 修改 wolultra 菜单位置到"服务"
WOL_MENU=$(find ./ ../feeds/ -path "*/luci-app-wolultra/root/usr/share/luci/menu.d/*.json" 2>/dev/null | head -n 1)
if [ -n "$WOL_MENU" ]; then
    sed -i 's#"admin/control/wolultra"#"admin/services/wolultra"#g; s#"admin/control"#"admin/services"#g' "$WOL_MENU"
    echo "wolultra menu moved to services"
fi
