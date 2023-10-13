#!/bin/bash

# 更新系统软件包
apt update
apt -y upgrade

# 安装OpenVPN和必要的组件
apt -y install openvpn easy-rsa

# 设置OpenVPN服务器环境
make-cadir /etc/openvpn/easy-rsa
cd /etc/openvpn/easy-rsa

# 编辑vars文件
cat <<EOF > vars
export KEY_COUNTRY="YourCountry"
export KEY_PROVINCE="YourProvince"
export KEY_CITY="YourCity"
export KEY_ORG="YourOrganization"
export KEY_EMAIL="YourEmail"
export KEY_CN=45.32.129.214
EOF

# 初始化PKI
source vars
./clean-all
./build-ca
./build-key-server server
./build-dh
openvpn --genkey --secret keys/ta.key

# 配置OpenVPN服务器
cat <<EOF > /etc/openvpn/server.conf
port 1194
proto udp
dev tun
ca /etc/openvpn/easy-rsa/keys/ca.crt
cert /etc/openvpn/easy-rsa/keys/server.crt
key /etc/openvpn/easy-rsa/keys/server.key
dh /etc/openvpn/easy-rsa/keys/dh2048.pem
server 10.8.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
cipher AES-256-CBC
tls-auth /etc/openvpn/easy-rsa/keys/ta.key 0
comp-lzo
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn/status.log
verb 3
EOF

# 设置IP转发
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# 启动OpenVPN服务
systemctl start openvpn@server
systemctl enable openvpn@server

# 配置防火墙
ufw allow OpenSSH
ufw allow 1194/udp
ufw enable

# 生成客户端配置文件
mkdir -p /etc/openvpn/client-configs/files
chmod 700 /etc/openvpn/client-configs/files
cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf /etc/openvpn/client-configs/base.conf

# 生成客户端配置文件
cat <<EOF > /etc/openvpn/client-configs/base.conf
<connection>
remote 45.32.129.214 1194
user nobody
group nogroup
persist-key
persist-tun
ca ca.crt
cert client1.crt
key client1.key
remote-cert-tls server
cipher AES-256-CBC
comp-lzo
</connection>
EOF

# 配置客户端证书访问权限
cp /etc/openvpn/easy-rsa/keys/{ca.crt,client1.crt,client1.key,ta.key} /etc/openvpn/client-configs/files/

# 显示安装完成信息
echo "OpenVPN安装完成！"
echo "您可以在 /etc/openvpn/client-configs/files 目录中找到生成的客户端配置文件。"
echo "请将相应的客户端配置文件下载到本地计算机上，并使用OpenVPN客户端加载它们以连接到您的OpenVPN服务器。"