#!/usr/bin/env bash

#====================================================
#	System Request:Debian 10+/Ubuntu 20.04+/Centos 8+
#	Author:	wulabing
#	Dscription: Xray onekey Management
#	email: admin@wulabing.com
#====================================================

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
stty erase ^?

cd "$(
  cd "$(dirname "$0")" || exit
  pwd
)" || exit

# ������ɫ����
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
Blue="\033[36m"
Font="\033[0m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
OK="${Green}[OK]${Font}"
ERROR="${Red}[ERROR]${Font}"

# ����
shell_version="0.2.2"
github_branch="nginx_forward"
xray_conf_dir="/usr/local/etc/xray"
website_dir="/www/xray_web/"
xray_access_log="/var/log/xray/access.log"
xray_error_log="/var/log/xray/error.log"
cert_dir="/usr/local/etc/xray"
domain_tmp_dir="/usr/local/etc/xray"
nginx_conf_dir="/etc/nginx/conf/conf.d"
compatible_nginx_conf="no"

cert_group="nobody"
random_num=$((RANDOM % 12 + 4))

VERSION=$(echo "${VERSION}" | awk -F "[()]" '{print $2}')
WS_PATH="/$(head -n 10 /dev/urandom | md5sum | head -c ${random_num})/"

function shell_mode_check() {
  if [ -f ${xray_conf_dir}/config.json ]; then
    if [ "$(grep -c "wsSettings" ${xray_conf_dir}/config.json)" -ge 1 ]; then
      shell_mode="ws"
    fi
  else
    shell_mode="None"
  fi
}
function print_ok() {
  echo -e "${OK} ${Blue} $1 ${Font}"
}

function print_error() {
  echo -e "${ERROR} ${RedBG} $1 ${Font}"
}

function is_root() {
  if [[ 0 == "$UID" ]]; then
    print_ok "��ǰ�û��� root �û�����ʼ��װ����"
  else
    print_error "��ǰ�û����� root �û������л��� root �û�������ִ�нű�"
    exit 1
  fi
}

judge() {
  if [[ 0 -eq $? ]]; then
    print_ok "$1 ���"
    sleep 1
  else
    print_error "$1 ʧ��"
    exit 1
  fi
}

function system_check() {
  source '/etc/os-release'

  if [[ "${ID}" == "centos" && ${VERSION_ID} -ge 7 ]]; then
    if [[ ${VERSION_ID} -ge 8 ]]; then
      compatible_nginx_conf="no"
    else
      compatible_nginx_conf="yes"
    fi
    print_ok "��ǰϵͳΪ Centos ${VERSION_ID} ${VERSION}"
    INS="yum install -y"
    wget -N -P /etc/yum.repos.d/ https://raw.githubusercontent.com/wulabing/Xray_onekey/${github_branch}/basic/nginx.repo
  elif [[ "${ID}" == "ol" ]]; then
    print_ok "��ǰϵͳΪ Oracle Linux ${VERSION_ID} ${VERSION}"
    INS="yum install -y"
    compatible_nginx_conf="yes"
    wget -N -P /etc/yum.repos.d/ https://raw.githubusercontent.com/wulabing/Xray_onekey/${github_branch}/basic/nginx.repo
  elif [[ "${ID}" == "debian" && ${VERSION_ID} -ge 9 ]]; then
    if [[ ${VERSION_ID} -ge 10 ]]; then
      compatible_nginx_conf="no"
    else
      compatible_nginx_conf="yes"
    fi
    print_ok "��ǰϵͳΪ Debian ${VERSION_ID} ${VERSION}"
    INS="apt install -y"
    # ������ܵ���������
    rm -f /etc/apt/sources.list.d/nginx.list
    # nginx ��װԤ����
    $INS curl gnupg2 ca-certificates lsb-release debian-archive-keyring
    curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
    | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
    http://nginx.org/packages/debian `lsb_release -cs` nginx" \
    | tee /etc/apt/sources.list.d/nginx.list
    echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" \
    | tee /etc/apt/preferences.d/99nginx

    apt update
  elif [[ "${ID}" == "ubuntu" && $(echo "${VERSION_ID}" | cut -d '.' -f1) -ge 18 ]]; then
    print_ok "��ǰϵͳΪ Ubuntu ${VERSION_ID} ${UBUNTU_CODENAME}"
    if [[ ${VERSION_ID} -ge 20 ]]; then
      compatible_nginx_conf="no"
    else
      compatible_nginx_conf="yes"
    fi
    INS="apt install -y"
    # ������ܵ���������
    rm -f /etc/apt/sources.list.d/nginx.list
    # nginx ��װԤ����
    $INS curl gnupg2 ca-certificates lsb-release ubuntu-keyring
    curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
    | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
    http://nginx.org/packages/ubuntu `lsb_release -cs` nginx" \
    | tee /etc/apt/sources.list.d/nginx.list
    echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" \
    | tee /etc/apt/preferences.d/99nginx

    apt update
  else
    print_error "��ǰϵͳΪ ${ID} ${VERSION_ID} ����֧�ֵ�ϵͳ�б���"
    exit 1
  fi

  if [[ $(grep "nogroup" /etc/group) ]]; then
    cert_group="nogroup"
  fi

  $INS dbus

  # �رո������ǽ
  systemctl stop firewalld
  systemctl disable firewalld
  systemctl stop nftables
  systemctl disable nftables
  systemctl stop ufw
  systemctl disable ufw
}

function nginx_install() {
  if ! command -v nginx >/dev/null 2>&1; then
    ${INS} nginx
    judge "Nginx ��װ"
  else
    print_ok "Nginx �Ѵ���"
    # ��ֹ�����쳣
    ${INS} nginx
  fi
  # �������⴦��
  mkdir -p /etc/nginx/conf.d >/dev/null 2>&1
}
function dependency_install() {
  ${INS} wget lsof tar
  judge "��װ wget lsof tar"

  if [[ "${ID}" == "centos" || "${ID}" == "ol" ]]; then
    ${INS} crontabs
  else
    ${INS} cron
  fi
  judge "��װ crontab"

  if [[ "${ID}" == "centos" || "${ID}" == "ol" ]]; then
    touch /var/spool/cron/root && chmod 600 /var/spool/cron/root
    systemctl start crond && systemctl enable crond
  else
    touch /var/spool/cron/crontabs/root && chmod 600 /var/spool/cron/crontabs/root
    systemctl start cron && systemctl enable cron

  fi
  judge "crontab ���������� "

  ${INS} unzip
  judge "��װ unzip"

  ${INS} curl
  judge "��װ curl"

  # upgrade systemd
  ${INS} systemd
  judge "��װ/���� systemd"

  # Nginx ���� ������� ������Ҫ
  #  if [[ "${ID}" == "centos" ||  "${ID}" == "ol" ]]; then
  #    yum -y groupinstall "Development tools"
  #  else
  #    ${INS} build-essential
  #  fi
  #  judge "���빤�߰� ��װ"

  if [[ "${ID}" == "centos" ]]; then
    ${INS} pcre pcre-devel zlib-devel epel-release openssl openssl-devel
  elif [[ "${ID}" == "ol" ]]; then
    ${INS} pcre pcre-devel zlib-devel openssl openssl-devel
    # Oracle Linux ��ͬ���ڰ汾�� VERSION_ID �Ƚ��� ֱ�ӱ�������
    yum-config-manager --enable ol7_developer_EPEL >/dev/null 2>&1
    yum-config-manager --enable ol8_developer_EPEL >/dev/null 2>&1
  else
    ${INS} libpcre3 libpcre3-dev zlib1g-dev openssl libssl-dev
  fi

  ${INS} jq

  if ! command -v jq; then
    wget -P /usr/bin https://raw.githubusercontent.com/wulabing/Xray_onekey/${github_branch}/binary/jq && chmod +x /usr/bin/jq
    judge "��װ jq"
  fi

  # ��ֹ����ϵͳxray��Ĭ��binĿ¼ȱʧ
  mkdir /usr/local/bin >/dev/null 2>&1
}

function basic_optimization() {
  # ����ļ�����
  sed -i '/^\*\ *soft\ *nofile\ *[[:digit:]]*/d' /etc/security/limits.conf
  sed -i '/^\*\ *hard\ *nofile\ *[[:digit:]]*/d' /etc/security/limits.conf
  echo '* soft nofile 65536' >>/etc/security/limits.conf
  echo '* hard nofile 65536' >>/etc/security/limits.conf

  # �ر� Selinux
  if [[ "${ID}" == "centos" || "${ID}" == "ol" ]]; then
    sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
    setenforce 0
  fi
}

function domain_check() {
  read -rp "���������������Ϣ(eg: www.wulabing.com):" domain
  domain_ip=$(curl -sm8 ipget.net/?ip="${domain}")
  print_ok "���ڻ�ȡ IP ��ַ��Ϣ�������ĵȴ�"
  wgcfv4_status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
  wgcfv6_status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
  if [[ ${wgcfv4_status} =~ "on"|"plus" ]] || [[ ${wgcfv6_status} =~ "on"|"plus" ]]; then
    # �ر�wgcf-warp���Է�����VPS IP���
    wg-quick down wgcf >/dev/null 2>&1
    print_ok "�ѹر� wgcf-warp"
  fi
  local_ipv4=$(curl -s4m8 https://ifconfig.co/)
  local_ipv6=$(curl -s6m8 https://ifconfig.co/)
  if [[ -z ${local_ipv4} && -n ${local_ipv6} ]]; then
    # ��IPv6 VPS���Զ����DNS64�������Ա�acme.sh����֤��ʹ��
    echo -e nameserver 2a01:4f8:c2c:123f::1 > /etc/resolv.conf
    print_ok "ʶ��Ϊ IPv6 Only �� VPS���Զ���� DNS64 ������"
  fi
  echo -e "����ͨ�� DNS ������ IP ��ַ��${domain_ip}"
  echo -e "�������� IPv4 ��ַ�� ${local_ipv4}"
  echo -e "�������� IPv6 ��ַ�� ${local_ipv6}"
  sleep 2
  if [[ ${domain_ip} == "${local_ipv4}" ]]; then
    print_ok "����ͨ�� DNS ������ IP ��ַ�� ���� IPv4 ��ַƥ��"
    sleep 2
  elif [[ ${domain_ip} == "${local_ipv6}" ]]; then
    print_ok "����ͨ�� DNS ������ IP ��ַ�� ���� IPv6 ��ַƥ��"
    sleep 2
  else
    print_error "��ȷ�������������ȷ�� A / AAAA ��¼�������޷�����ʹ�� xray"
    print_error "����ͨ�� DNS ������ IP ��ַ�� ���� IPv4 / IPv6 ��ַ��ƥ�䣬�Ƿ������װ����y/n��" && read -r install
    case $install in
    [yY][eE][sS] | [yY])
      print_ok "������װ"
      sleep 2
      ;;
    *)
      print_error "��װ��ֹ"
      exit 2
      ;;
    esac
  fi
}

function port_exist_check() {
  if [[ 0 -eq $(lsof -i:"$1" | grep -i -c "listen") ]]; then
    print_ok "$1 �˿�δ��ռ��"
    sleep 1
  else
    print_error "��⵽ $1 �˿ڱ�ռ�ã�����Ϊ $1 �˿�ռ����Ϣ"
    lsof -i:"$1"
    print_error "5s �󽫳����Զ� kill ռ�ý���"
    sleep 5
    lsof -i:"$1" | awk '{print $2}' | grep -v "PID" | xargs kill -9
    print_ok "kill ���"
    sleep 1
  fi
}
function update_sh() {
  ol_version=$(curl -L -s https://raw.githubusercontent.com/wulabing/Xray_onekey/${github_branch}/install.sh | grep "shell_version=" | head -1 | awk -F '=|"' '{print $3}')
  if [[ "$shell_version" != "$(echo -e "$shell_version\n$ol_version" | sort -rV | head -1)" ]]; then
    print_ok "�����°汾���Ƿ���� [Y/N]?"
    read -r update_confirm
    case $update_confirm in
    [yY][eE][sS] | [yY])
      wget -N --no-check-certificate https://raw.githubusercontent.com/wulabing/Xray_onekey/${github_branch}/install.sh
      print_ok "�������"
      print_ok "������ͨ�� bash $0 ִ�б�����"
      exit 0
      ;;
    *) ;;
    esac
  else
    print_ok "��ǰ�汾Ϊ���°汾"
    print_ok "������ͨ�� bash $0 ִ�б�����"
  fi
}

function xray_tmp_config_file_check_and_use() {
  if [[ -s ${xray_conf_dir}/config_tmp.json ]]; then
    mv -f ${xray_conf_dir}/config_tmp.json ${xray_conf_dir}/config.json
  else
    print_error "xray �����ļ��޸��쳣"
  fi
}

function modify_UUID() {
  [ -z "$UUID" ] && UUID=$(cat /proc/sys/kernel/random/uuid)
  cat ${xray_conf_dir}/config.json | jq 'setpath(["inbounds",0,"settings","clients",0,"id"];"'${UUID}'")' >${xray_conf_dir}/config_tmp.json
  xray_tmp_config_file_check_and_use
  judge "Xray TCP UUID �޸�"
}

function modify_ws() {
  cat ${xray_conf_dir}/config.json | jq 'setpath(["inbounds",0,"streamSettings","wsSettings","path"];"'${WS_PATH}'")' >${xray_conf_dir}/config_tmp.json
  xray_tmp_config_file_check_and_use
  judge "Xray ws �޸�"
}

function modify_nginx_port() {
  sed -i "/ssl http2;$/c \\\tlisten ${PORT} ssl http2;" ${nginx_conf}
  sed -i "3c \\\tlisten [::]:${PORT} ssl http2;" ${nginx_conf}
  judge "Xray port �޸�"
}

function modify_nginx_ws(){
  sed -i "/location/c \\\tlocation ${WS_PATH}" ${nginx_conf}
  judge "Nginx ws �޸�"
}

function modify_nginx_other() {
  modify_nginx_ws
  sed -i "/proxy_pass/c \\\tproxy_pass http://127.0.0.1:${inbound_port};" ${nginx_conf}
}



function modify_port() {
  read -rp "������˿ں�(Ĭ�ϣ�443)��" PORT
  [ -z "$PORT" ] && PORT="443"
  if [[ $PORT -le 0 ]] || [[ $PORT -gt 65535 ]]; then
    print_error "������ 0-65535 ֮���ֵ"
    exit 1
  fi
  port_exist_check $PORT
  modify_nginx_port
}

function configure_nginx_temp(){
  nginx_conf="/etc/nginx/conf.d/${domain}.conf"
  cd /etc/nginx/conf.d/ && rm -f ${domain}.conf
  wget -O ${domain}.conf https://raw.githubusercontent.com/wulabing/Xray_onekey/${github_branch}/config/web_temp.conf
  sed -i "s/xxx/${domain}/g" ${nginx_conf}
}

function configure_nginx() {
  nginx_conf="/etc/nginx/conf.d/${domain}.conf"
  cd /etc/nginx/conf.d/ && rm -f ${domain}.conf
  if [[ $compatible_nginx_conf == "yes" ]]; then
    wget -O ${domain}.conf https://raw.githubusercontent.com/wulabing/Xray_onekey/${github_branch}/config/web_compatible.conf
  elif [[ $compatible_nginx_conf == "no" ]]; then
    wget -O ${domain}.conf https://raw.githubusercontent.com/wulabing/Xray_onekey/${github_branch}/config/web.conf
  fi
  sed -i "s/xxx/${domain}/g" ${nginx_conf}
  modify_port
  modify_nginx_other
  systemctl restart nginx
}


function modify_inbound_port() {
  inbound_port=$((RANDOM + 10000))
  cat ${xray_conf_dir}/config.json | jq 'setpath(["inbounds",0,"port"];'${inbound_port}')' >${xray_conf_dir}/config_tmp.json
  xray_tmp_config_file_check_and_use
  judge "Xray inbound_port �޸�"
}

function configure_xray_ws() {
  cd /usr/local/etc/xray && rm -f config.json && wget -O config.json https://raw.githubusercontent.com/wulabing/Xray_onekey/${github_branch}/config/xray_tls_ws.json
  modify_UUID
  modify_ws
  modify_inbound_port
}

function xray_install() {
  print_ok "��װ Xray"
  curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh | bash -s -- install
  judge "Xray ��װ"

  # �������� Xray �ĵ�������
  echo $domain >$domain_tmp_dir/domain
  judge "������¼"
}

function ssl_install() {
  #  ʹ�� Nginx ���ǩ�� ���谲װ�������
  #  if [[ "${ID}" == "centos" ||  "${ID}" == "ol" ]]; then
  #    ${INS} socat nc
  #  else
  #    ${INS} socat netcat
  #  fi
  #  judge "��װ SSL ֤�����ɽű�����"

  curl -L get.acme.sh | bash
  judge "��װ SSL ֤�����ɽű�"
}

function acme() {
  "$HOME"/.acme.sh/acme.sh --set-default-ca --server letsencrypt

  systemctl restart nginx

  if "$HOME"/.acme.sh/acme.sh --issue -d "${domain}" -k ec-256 --webroot "$website_dir" --force; then
    print_ok "SSL ֤�����ɳɹ�"
    sleep 2
    if "$HOME"/.acme.sh/acme.sh --installcert -d "${domain}" --fullchainpath /ssl/xray.crt --keypath /ssl/xray.key --reloadcmd "systemctl restart xray" --reloadcmd "systemctl restart nginx" --ecc --force; then
      print_ok "SSL ֤�����óɹ�"
      sleep 2
      if [[ -n $(type -P wgcf) && -n $(type -P wg-quick) ]]; then
        wg-quick up wgcf >/dev/null 2>&1
        print_ok "������ wgcf-warp"
      fi
    fi
  elif "$HOME"/.acme.sh/acme.sh --issue -d "${domain}" -k ec-256 --webroot "$website_dir" --force --listen-v6; then
    print_ok "SSL ֤�����ɳɹ�"
    sleep 2
    if "$HOME"/.acme.sh/acme.sh --installcert -d "${domain}" --fullchainpath /ssl/xray.crt --keypath /ssl/xray.key --reloadcmd "systemctl restart xray" --reloadcmd "systemctl restart nginx" --ecc --force; then
      print_ok "SSL ֤�����óɹ�"
      sleep 2
      if [[ -n $(type -P wgcf) && -n $(type -P wg-quick) ]]; then
        wg-quick up wgcf >/dev/null 2>&1
        print_ok "������ wgcf-warp"
      fi
    fi
  else
    print_error "SSL ֤������ʧ��"
    rm -rf "$HOME/.acme.sh/${domain}_ecc"
    if [[ -n $(type -P wgcf) && -n $(type -P wg-quick) ]]; then
      wg-quick up wgcf >/dev/null 2>&1
      print_ok "������ wgcf-warp"
    fi
    exit 1
  fi

}

function ssl_judge_and_install() {

  mkdir -p /ssl >/dev/null 2>&1
  if [[ -f "/ssl/xray.key" || -f "/ssl/xray.crt" ]]; then
    print_ok "/ssl Ŀ¼��֤���ļ��Ѵ���"
    print_ok "�Ƿ�ɾ�� /ssl Ŀ¼�µ�֤���ļ� [Y/N]?"
    read -r ssl_delete
    case $ssl_delete in
    [yY][eE][sS] | [yY])
      rm -rf /ssl/*
      print_ok "��ɾ��"
      ;;
    *) ;;

    esac
  fi

  if [[ -f "/ssl/xray.key" || -f "/ssl/xray.crt" ]]; then
    echo "֤���ļ��Ѵ���"
  elif [[ -f "$HOME/.acme.sh/${domain}_ecc/${domain}.key" && -f "$HOME/.acme.sh/${domain}_ecc/${domain}.cer" ]]; then
    echo "֤���ļ��Ѵ���"
    "$HOME"/.acme.sh/acme.sh --installcert -d "${domain}" --fullchainpath /ssl/xray.crt --keypath /ssl/xray.key --ecc
    judge "֤��Ӧ��"
  else
    mkdir /ssl
    ssl_install
    acme
  fi

  # Xray Ĭ���� nobody �û����У�֤��Ȩ������
  chown -R nobody.$cert_group /ssl/*
}

function generate_certificate() {
  if [[ -z ${local_ipv4} && -n ${local_ipv6} ]]; then
    signedcert=$(xray tls cert -domain="$local_ipv6" -name="$local_ipv6" -org="$local_ipv6" -expire=87600h)
  else
    signedcert=$(xray tls cert -domain="$local_ipv4" -name="$local_ipv4" -org="$local_ipv4" -expire=87600h)
  fi
  echo $signedcert | jq '.certificate[]' | sed 's/\"//g' | tee $cert_dir/self_signed_cert.pem
  echo $signedcert | jq '.key[]' | sed 's/\"//g' >$cert_dir/self_signed_key.pem
  openssl x509 -in $cert_dir/self_signed_cert.pem -noout || print_error "������ǩ��֤��ʧ��" && exit 1
  print_ok "������ǩ��֤��ɹ�"
  chown nobody.$cert_group $cert_dir/self_signed_cert.pem
  chown nobody.$cert_group $cert_dir/self_signed_key.pem
}

function configure_web() {
  rm -rf /www/xray_web
  mkdir -p /www/xray_web
  print_ok "�Ƿ�����αװ��ҳ��[Y/N]"
  read -r webpage
  case $webpage in
  [yY][eE][sS] | [yY])
    wget -O web.tar.gz https://raw.githubusercontent.com/wulabing/Xray_onekey/main/basic/web.tar.gz
    tar xzf web.tar.gz -C /www/xray_web
    judge "վ��αװ"
    rm -f web.tar.gz
    ;;
  *) ;;
  esac
}

function xray_uninstall() {
  curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh | bash -s -- remove --purge
  rm -rf $website_dir
  print_ok "�Ƿ�ж��nginx [Y/N]?"
  read -r uninstall_nginx
  case $uninstall_nginx in
  [yY][eE][sS] | [yY])
    if [[ "${ID}" == "centos" || "${ID}" == "ol" ]]; then
      yum remove nginx -y
    else
      apt purge nginx -y
    fi
    ;;
  *) ;;
  esac
  print_ok "�Ƿ�ж��acme.sh [Y/N]?"
  read -r uninstall_acme
  case $uninstall_acme in
  [yY][eE][sS] | [yY])
    /root/.acme.sh/acme.sh --uninstall
    rm -rf /root/.acme.sh
    rm -rf /ssl/
    ;;
  *) ;;
  esac
  print_ok "ж�����"
  exit 0
}

function restart_all() {
  systemctl restart nginx
  judge "Nginx ����"
  systemctl restart xray
  judge "Xray ����"
}


function ws_information() {
  DOMAIN=$(cat ${domain_tmp_dir}/domain)
  UUID=$(cat ${xray_conf_dir}/config.json | jq .inbounds[0].settings.clients[0].id | tr -d '"')
  PORT=$(cat "/etc/nginx/conf.d/${DOMAIN}.conf" | grep 'ssl http2' | awk -F ' ' '{print $2}' )
  FLOW=$(cat ${xray_conf_dir}/config.json | jq .inbounds[0].settings.clients[0].flow | tr -d '"')
  WS_PATH=$(cat ${xray_conf_dir}/config.json | jq .inbounds[0].streamSettings.wsSettings.path | tr -d '"')


  echo -e "${Red} Xray ������Ϣ ${Font}"
  echo -e "${Red} ��ַ��address��:${Font}  $DOMAIN"
  echo -e "${Red} �˿ڣ�port����${Font}  $PORT"
  echo -e "${Red} �û� ID��UUID����${Font} $UUID"
  echo -e "${Red} ���ܷ�ʽ��security����${Font} none "
  echo -e "${Red} ����Э�飨network����${Font} ws "
  echo -e "${Red} αװ���ͣ�type����${Font} none "
  echo -e "${Red} ·����path����${Font} $WS_PATH "
  echo -e "${Red} �ײ㴫�䰲ȫ��${Font} tls "
}

function ws_link() {
  DOMAIN=$(cat ${domain_tmp_dir}/domain)
  UUID=$(cat ${xray_conf_dir}/config.json | jq .inbounds[0].settings.clients[0].id | tr -d '"')
  PORT=$(cat "/etc/nginx/conf.d/${DOMAIN}.conf" | grep 'ssl http2' | awk -F ' ' '{print $2}' )
  FLOW=$(cat ${xray_conf_dir}/config.json | jq .inbounds[0].settings.clients[0].flow | tr -d '"')
  WS_PATH=$(cat ${xray_conf_dir}/config.json | jq .inbounds[0].streamSettings.wsSettings.path | tr -d '"')
  WS_PATH_WITHOUT_SLASH=$(echo $WS_PATH | tr -d '/')

  print_ok "URL ���ӣ�VLESS + WebSocket + TLS��"
  print_ok "vless://$UUID@$DOMAIN:$PORT?type=ws&security=tls&path=%2f${WS_PATH_WITHOUT_SLASH}%2f#WS_TLS_wulabing-$DOMAIN"
  print_ok "URL ��ά�루VLESS + WebSocket + TLS��������������з��ʣ�"
  print_ok "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=vless://$UUID@$DOMAIN:$PORT?type=ws%26security=tls%26path=%2f${WS_PATH_WITHOUT_SLASH}%2f%23WS_TLS_wulabing-$DOMAIN"
}

function basic_ws_information() {
  print_ok "VLESS + TCP + TLS + Nginx + WebSocket ��װ�ɹ�"
  ws_information
  print_ok "������������������������������������������������"
  ws_link
}

function show_access_log() {
  [ -f ${xray_access_log} ] && tail -f ${xray_access_log} || echo -e "${RedBG}log�ļ�������${Font}"
}

function show_error_log() {
  [ -f ${xray_error_log} ] && tail -f ${xray_error_log} || echo -e "${RedBG}log�ļ�������${Font}"
}

function bbr_boost_sh() {
  [ -f "tcp.sh" ] && rm -rf ./tcp.sh
  wget -N --no-check-certificate "https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
}

function mtproxy_sh() {
  wget -N --no-check-certificate "https://github.com/wulabing/mtp/raw/master/mtproxy.sh" && chmod +x mtproxy.sh && bash mtproxy.sh
}

function install_xray_ws() {
  is_root
  system_check
  dependency_install
  basic_optimization
  domain_check
  port_exist_check 80
  xray_install
  configure_xray_ws
  nginx_install
  configure_nginx_temp
  configure_web
  ssl_judge_and_install
  configure_nginx
  restart_all
  basic_ws_information
}

menu() {
  update_sh
  shell_mode_check
  echo -e "\t Xray ��װ����ű� ${Red}[${shell_version}]${Font}"
  echo -e "\t---authored by wulabing---"
  echo -e "\thttps://github.com/wulabing\n"

  echo -e "��ǰ�Ѱ�װ�汾��${shell_mode}"
  echo -e "���������������������������� ��װ�� ����������������������������"""
  echo -e "${Green}0.${Font}  ���� �ű�"
  echo -e "${Green}1.${Font}  ��װ Xray (VLESS + TCP + TLS + Nginx + WebSocket)"
  echo -e "���������������������������� ���ñ�� ����������������������������"
  echo -e "${Green}11.${Font} ��� UUID"
  echo -e "${Green}13.${Font} ��� ���Ӷ˿�"
  echo -e "${Green}14.${Font} ��� WebSocket PATH"
  echo -e "���������������������������� �鿴��Ϣ ����������������������������"
  echo -e "${Green}21.${Font} �鿴 ʵʱ������־"
  echo -e "${Green}22.${Font} �鿴 ʵʱ������־"
  echo -e "${Green}23.${Font} �鿴 Xray ��������"
  #    echo -e "${Green}23.${Font}  �鿴 V2Ray ������Ϣ"
  echo -e "���������������������������� ����ѡ�� ����������������������������"
  echo -e "${Green}31.${Font} ��װ 4 �� 1 BBR�����ٰ�װ�ű�"
  echo -e "${Yellow}32.${Font} ��װ MTproxy(���Ƽ�ʹ��,������û��رջ�ж��)"
  echo -e "${Green}33.${Font} ж�� Xray"
  echo -e "${Green}34.${Font} ���� Xray-core"
  echo -e "${Green}35.${Font} ��װ Xray-core ���԰�(Pre)"
  echo -e "${Green}36.${Font} �ֶ�����SSL֤��"
  echo -e "${Green}40.${Font} �˳�"
  read -rp "���������֣�" menu_num
  case $menu_num in
  0)
    update_sh
    ;;
  1)
    install_xray_ws
    ;;
  11)
    read -rp "������UUID:" UUID
    modify_UUID
    restart_all
    ;;
  13)
    DOMAIN=$(cat ${domain_tmp_dir}/domain)
    nginx_conf="/etc/nginx/conf.d/${DOMAIN}.conf"
    modify_port
    restart_all
    ;;
  14)
    DOMAIN=$(cat ${domain_tmp_dir}/domain)
    nginx_conf="/etc/nginx/conf.d/${DOMAIN}.conf"
    read -rp "������·��(ʾ����/wulabing/ Ҫ�����඼����/):" WS_PATH
    modify_ws
    modify_nginx_ws
    restart_all
    ;;
  21)
    tail -f $xray_access_log
    ;;
  22)
    tail -f $xray_error_log
    ;;
  23)
    if [[ -f $xray_conf_dir/config.json ]]; then
      basic_ws_information
    else
      print_error "xray �����ļ�������"
    fi
    ;;
  31)
    bbr_boost_sh
    ;;
  32)
    mtproxy_sh
    ;;
  33)
    source '/etc/os-release'
    xray_uninstall
    ;;
  34)
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" - install
    restart_all
    ;;
  35)
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" - install --beta
    restart_all
    ;;
  36)
    "/root/.acme.sh"/acme.sh --cron --home "/root/.acme.sh"
    restart_all
    ;;
  40)
    exit 0
    ;;
  *)
    print_error "��������ȷ������"
    ;;
  esac
}
menu "$@"