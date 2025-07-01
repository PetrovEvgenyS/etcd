#!/bin/bash

# Нужно создать отдельного пользователя
# Нужно, чтобы etcd писал логи в отдельную директорию

### Определение цветовых кодов ###
ESC=$(printf '\033') RESET="${ESC}[0m" MAGENTA="${ESC}[35m"
magentaprint() { printf "${MAGENTA}%s${RESET}\n" "$1"; }

ETCD_VERSION="v3.5.18"  # Версию можно изменить здесь
https://github.com/etcd-io/etcd/releases/download/v3.6.0-rc.0/etcd-v3.6.0-rc.0-linux-amd64.tar.gz
install_etcd() {
    magentaprint "Скачиваем и устанавливаем etcd версии $ETCD_VERSION из официального релиза..."
    curl -L https://github.com/etcd-io/etcd/releases/download/$ETCD_VERSION/etcd-$ETCD_VERSION-linux-amd64.tar.gz -o etcd.tar.gz \
    || { echo "Ошибка при скачивании."; exit 1; }
    tar xzvf etcd.tar.gz || { echo "Ошибка при распаковке архива."; exit 1; }
    cd etcd-$ETCD_VERSION-linux-amd64 || { echo "Папка с etcd отсутствует."; exit 1; }
    cp etcd etcdctl /usr/local/bin/
    cd ..
    rm -rf etcd-$ETCD_VERSION-linux-amd64 etcd.tar.gz
    magentaprint "etcd $ETCD_VERSION установлен."
}

create_etcd_service() {
    mkdir -p /etc/etcd
    magentaprint "Создаём systemd-юнит для etcd..."
    cat <<EOF > /etc/systemd/system/etcd.service
[Unit]
Description=etcd $ETCD_VERSION - distributed reliable key-value store
After=network.target

[Service]
ExecStart=/usr/local/bin/etcd --config-file=/etc/etcd/etcd.conf
WorkingDirectory=/var/lib/etcd
Restart=always
User=root
LimitNOFILE=40000

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable etcd.service
    magentaprint "Юнит-файл etcd создан."
}

configure_etcd() {
    magentaprint "Настраиваем etcd..."
    local NODE_NAME=$1
    local NODE_IP=$2
    local CLUSTER_NODES="node-vm01=http://10.100.10.1:2380,node-vm02=http://10.100.10.2:2380,node-vm03=http://10.100.10.3:2380"
    mkdir -p /etc/etcd /var/lib/etcd
    cat <<EOF > /etc/etcd/etcd.conf
name: ${NODE_NAME}
data-dir: /var/lib/etcd
listen-peer-urls: http://${NODE_IP}:2380
listen-client-urls: http://${NODE_IP}:2379,http://127.0.0.1:2379
initial-advertise-peer-urls: http://${NODE_IP}:2380
advertise-client-urls: http://${NODE_IP}:2379
initial-cluster: ${CLUSTER_NODES}
initial-cluster-token: etcd-cluster
initial-cluster-state: new
EOF
    magentaprint "Конфигурация etcd завершена."
}

start_etcd() {
    magentaprint "Запускаем etcd..."
    systemctl start etcd || { echo "Ошибка запуска etcd."; exit 1; }
    magentaprint "etcd запущен."
}

check_status() {
    magentaprint "Проверяем статус etcd..."
    systemctl status etcd
}

main() {
    local NODE_NAME=$(hostname)
    local NODE_IP=$(hostname -I | awk '{print $1}')
    install_etcd
    create_etcd_service
    configure_etcd "$NODE_NAME" "$NODE_IP"
    start_etcd
    check_status
}

main
