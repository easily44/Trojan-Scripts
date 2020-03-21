#!/bin/bash

red='\e[91m'
green='\e[92m'
yellow='\e[93m'
magenta='\e[95m'
cyan='\e[96m'
none='\e[0m'

_red() { echo -e ${red}$*${none}; }
_green() { echo -e ${green}$*${none}; }
_yellow() { echo -e ${yellow}$*${none}; }
_magenta() { echo -e ${magenta}$*${none}; }
_cyan() { echo -e ${cyan}$*${none}; }

cmd="apt-get"

# Root
[[ $(id -u) != 0 ]] && echo -e "\n 哎呀……请使用 ${red}root ${none}用户运行 ${yellow}~(^_^) ${none}\n" && exit 1

# 笨笨的检测方法
if [[ $(command -v apt-get) || $(command -v yum) ]] && [[ $(command -v systemctl) ]]; then
    if [[ $(command -v yum) ]]; then
        cmd="yum"
    fi
else
    echo -e " 
        哈哈……这个 ${red}辣鸡脚本${none} 不支持你的系统。 ${yellow}(-_-) ${none}
        备注: 仅支持 Ubuntu 16+ / Debian 8+ / CentOS 7+ 系统
        " && exit 1
fi

install_info() {
    clear
    echo
    echo " ....准备安装了咯..看看有毛有配置正确了..."
    echo
    echo "---------- 安装信息 -------------"
    echo
    echo -e "$yellow Trojan 地址 = $cyan${trojan_domain}$none"
    echo
    echo -e "$yellow Trojan 端口 = $cyan$trojan_port$none"
    echo
    echo -e "$yellow Trojan 密码 = $cyan$trojan_password$none"
    echo
    echo -e "$yellow Nginx 反代地址 = $cyan$trojan_pretend_address$none"
    echo
    echo -e "$yellow Trojan SSL证书路径 = $cyan$trojan_ssl_cert$none"
    echo
    echo -e "$yellow Trojan SSL证书密钥路径 = $cyan$trojan_ssl_key$none"
    echo
    echo "---------- END -------------"
    echo
    pause
    echo
}

show_config_info() {
    clear
    echo
    echo "---------- Trojan 配置信息 -------------"
    echo
    echo -e "$yellow Trojan 地址 = $cyan${trojan_domain}$none"
    echo
    echo -e "$yellow Trojan 端口 = $cyan$trojan_port$none"
    echo
    echo -e "$yellow Trojan 密码 = $cyan$trojan_password$none"
    echo
    echo -e "$yellow Nginx 反代地址 = $cyan$trojan_pretend_address$none"
    echo
    echo -e "$yellow Trojan SSL证书路径 = $cyan$trojan_ssl_cert$none"
    echo
    echo -e "$yellow Trojan SSL证书密钥路径 = $cyan$trojan_ssl_key$none"
    echo
    echo "---------- END -------------"
    echo
    echo -e "$yellow Trojan Uri = trojan://$trojan_password@${trojan_domain}:$trojan_port $none"
}

main_install() {
    get_trojan_domain

    install_info

    install_dependencies
    install_nginx
    install_trojan

    show_config_info
}

main_uninstall() {
    systemctl stop trojan && systemctl disable trojan
    systemctl stop nginx && systemctl disable nginx

    if [[ $cmd == "apt-get" ]];then
        rm -rf /etc/nginx/sites-available/*
        rm -rf /etc/nginx/sites-enabled/*
    elif [[ $cmd == "yum" ]];then
        rm -rf /etc/nginx/sites-available
        rm -rf /etc/nginx/sites-enabled
        setsebool -P httpd_can_network_connect false
    fi

    rm -rf /usr/local/etc/trojan
}

install_dependencies() {
    if [[ $cmd == "apt=get" ]];then
        $cmd install libcap2-bin xz-utils nginx wget -y
    elif [[ $cmd == "yum" ]];then
        $cmd install epel-release -y
        $cmd install xz nginx wget -y
    fi
}

install_nginx() {
    if [[ $cmd == "yum" ]];then
        mkdir /etc/nginx/sites-available
        mkdir /etc/nginx/sites-enabled
        setsebool -P httpd_can_network_connect true
    elif [[ $cmd == "apt-get" ]];then
        rm /etc/nginx/sites-enabled/default
    fi
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
    rm -rf /etc/nginx/nginx.conf
    wget https://raw.githubusercontent.com/TheWanderingCoel/Trojan-Scripts/master/nginx.conf -O /etc/nginx/nginx.conf
    wget https://raw.githubusercontent.com/TheWanderingCoel/Trojan-Scripts/master/example.com -O /etc/nginx/sites-available/$trojan_domain
    get_ip
    sed -i "4s/<tdom.ml>/$trojan_domain/" /etc/nginx/sites-available/$trojan_domain
    sed -i "7s%<tdom.ml>%$trojan_pretend_address%" /etc/nginx/sites-available/$trojan_domain
    sed -i "15s/<10.10.10.10>/$ip/" /etc/nginx/sites-available/$trojan_domain
    sed -i "17s/<tdom.ml>/$trojan_domain/" /etc/nginx/sites-available/$trojan_domain
    ln -s /etc/nginx/sites-available/$trojan_domain /etc/nginx/sites-enabled/
    if [[ $cmd == "yum" ]];then
        firewall-cmd --zone=public --add-port=80/tcp --permanent
        firewall-cmd 
    fi
    systemctl restart nginx;
    systemctl enable nginx;
}

install_trojan() {
    mkdir /usr/local/etc/certfiles
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/trojan-gfw/trojan-quickstart/master/trojan-quickstart.sh)"
    cp /usr/local/etc/trojan/config.json /usr/local/etc/trojan/config.json.bak
    rm -rf /usr/local/etc/trojan/config.json
    wget https://raw.githubusercontent.com/TheWanderingCoel/Trojan-Scripts/master/config.json -O /usr/local/etc/trojan/config.json
    sed -i "8s/\"password1\"/\"$trojan_password\"/" /usr/local/etc/trojan/config.json
    sed -i "12s%\"/path/to/certificate.crt\"%\"$trojan_ssl_cert\"%" /usr/local/etc/trojan/config.json
    sed -i "13s%\"/path/to/private.key\"%\"$trojan_ssl_key\"%" /usr/local/etc/trojan/config.json
    if [[ $cmd == "yum" ]];then
        firewall-cmd --zone=public --add-port=443/tcp --permanent
        firewall-cmd --reload
    fi
    systemctl restart trojan
    systemctl enable trojan
}

get_ip() {
	ip=$(curl -s https://ipinfo.io/ip)
	[[ -z $ip ]] && ip=$(curl -s https://api.ip.sb/ip)
	[[ -z $ip ]] && ip=$(curl -s https://api.ipify.org)
	[[ -z $ip ]] && ip=$(curl -s https://ip.seeip.org)
	[[ -z $ip ]] && ip=$(curl -s https://ifconfig.co/ip)
	[[ -z $ip ]] && ip=$(curl -s https://api.myip.com | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}")
	[[ -z $ip ]] && ip=$(curl -s icanhazip.com)
	[[ -z $ip ]] && ip=$(curl -s myip.ipip.net | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}")
	[[ -z $ip ]] && echo -e "\n$red 这垃圾小鸡扔了吧！$none\n" && exit
}

domain_check() {
	# test_domain=$(dig $new_domain +short)
	# test_domain=$(ping $new_domain -c 1 -4 | grep -oE -m1 "([0-9]{1,3}\.){3}[0-9]{1,3}")
	# test_domain=$(wget -qO- --header='accept: application/dns-json' "https://cloudflare-dns.com/dns-query?name=$new_domain&type=A" | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" | head -1)
	test_domain=$(curl -sH 'accept: application/dns-json' "https://cloudflare-dns.com/dns-query?name=$trojan_domain&type=A" | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" | head -1)
	if [[ $test_domain != $ip ]]; then
		echo
		echo -e "$red 检测域名解析错误....$none"
		echo
		echo -e " 你的域名: $yellow$trojan_domain$none 未解析到: $cyan$ip$none"
		echo
		echo -e " 你的域名当前解析到: $cyan$test_domain$none"
		echo
		echo "备注...如果你的域名是使用 Cloudflare 解析的话..在 Status 那里点一下那图标..让它变灰"
		echo
		exit 1
	fi
}

error() {
	echo -e "\n$red 输入错误！$none\n"
}

pause() {
    read -rsp "$(echo -e "按$green Enter 回车键 $none继续....或按$red Ctrl + C $none取消.")" -d $'\n'
    echo
}

get_trojan_domain() {
    while :; do
        echo
		echo -e "请输入一个 $magenta正确的域名$none，一定一定一定要正确，不！能！出！错！"
		read -p "(例如：example.com): " trojan_domain
		[ -z "$trojan_domain" ] && error && continue
		echo
		echo
		echo -e "$yellow Trojan域名 = $cyan$trojan_domain$none"
		echo "----------------------------------------------------------------"
		break
	done
    get_ip
	echo
	echo
	echo -e "$yellow 请将 $magenta$trojan_domain$none $yellow解析到: $cyan$ip$none"
	echo
	echo -e "$yellow 请将 $magenta$trojan_domain$none $yellow解析到: $cyan$ip$none"
	echo
	echo -e "$yellow 请将 $magenta$trojan_domain$none $yellow解析到: $cyan$ip$none"
	echo "----------------------------------------------------------------"
	echo
    while :; do
		read -p "$(echo -e "(是否已经正确解析: [${magenta}Y$none]):") " record
		if [[ -z "$record" ]]; then
			error
		else
			if [[ "$record" == [Yy] ]]; then
				domain_check
				echo
				echo
				echo -e "$yellow 域名解析 = ${cyan}我确定已经有解析了$none"
				echo "----------------------------------------------------------------"
				echo
				break
			else
				error
			fi
		fi
	done
    get_trojan_port
}

get_trojan_port() {
    while :; do
        local port=443
        echo -e "请输入 "$yellow"Trojan"$none" 端口 ["$magenta"1-65535"$none"]"
        read -p "$(echo -e "(默认端口: ${cyan}${port}$none):")" trojan_port
        [ -z "$trojan_port" ] && trojan_port=$port
        case $trojan_port in
        [1-9] | [1-9][0-9] | [1-9][0-9][0-9] | [1-9][0-9][0-9][0-9] | [1-5][0-9][0-9][0-9][0-9] | 6[0-4][0-9][0-9][0-9] | 65[0-4][0-9][0-9] | 655[0-3][0-5])
            echo
            echo 
            echo -e "$yellow Trojan 端口 = $cyan$trojan_port$none"
            echo "----------------------------------------------------------------"
            echo
            break
            ;;
        *)
            error
            ;;
        esac
    done
    get_trojan_password
}

get_trojan_password() {
    while :; do
        local default="Trojan"
        echo -e "请输入Trojan的密码"
        read -p "$(echo -e "(默认密码: ${cyan}${default}$none):")" trojan_password
        [ -z "$trojan_password" ] && trojan_password=$default
        echo
        echo
        echo -e "$yellow Trojan 密码 = $cyan$trojan_password$none"
        echo "----------------------------------------------------------------"
        echo
        break
    done
    get_trojan_pretend_address
}

get_trojan_pretend_address() {
    while :; do
        local address=https://www.ietf.org
        echo -e "请输入Nginx反代的地址"
        read -p "$(echo -e "(默认地址: ${cyan}${address}$none):")" trojan_pretend_address
        [ -z "$trojan_pretend_address" ] && trojan_pretend_address=$address
        echo
        echo
        echo -e "$yellow Nginx 反代地址 = $cyan$trojan_pretend_address$none"
        echo "----------------------------------------------------------------"
        echo
        break
    done
    get_trojan_ssl_cert
}

get_trojan_ssl_cert() {
    while :; do
        local default="/usr/local/etc/certfiles/certificate.pem"
        echo -e "请输入Trojan SSL证书的路径"
        read -p "$(echo -e "(默认路径: ${cyan}${default}$none):")" trojan_ssl_cert
        [ -z "$trojan_ssl_cert" ] && trojan_ssl_cert=$default
        echo
        echo
        echo -e "$yellow Trojan SSL证书路径 = $cyan$trojan_ssl_cert$none"
        echo "----------------------------------------------------------------"
        echo
        break
    done
    get_trojan_ssl_key
}

get_trojan_ssl_key() {
    while :; do
        local default="/usr/local/etc/certfiles/private_key.pem"
        echo -e "请输入Trojan SSL证书密钥的路径"
        read -p "$(echo -e "(默认路径: ${cyan}${default}$none):")" trojan_ssl_key
        [ -z "$trojan_ssl_key" ] && trojan_ssl_key=$default
        echo
        echo
        echo -e "$yellow Trojan SSL证书密钥路径 = $cyan$trojan_ssl_key$none"
        echo "----------------------------------------------------------------"
        echo
        break
    done
}

clear
while :; do
    echo "........... Trojan一键脚本 by TheWanderingCoel ..........."
    echo
    echo "Github: https://github.com/TheWanderingCoel"
    echo
    echo "V2ray客户端: https://github.com/TheWanderingCoel/Trojan-Qt5" 
    echo
    echo "参考&基于: https://github.com/233boy/v2ray"
    echo
    echo "1. 安装"
    echo
    echo "2. 卸载"
    echo
    read -p "$(echo -e "请选择 [${magenta}1-2$none]:")" choice
    case $choice in
        1)
            main_install
            break
            ;;
        2)
            main_uninstall
            break
            ;;
        *)
            error
            ;;
        esac
done
