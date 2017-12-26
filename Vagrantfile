BOX_OS = "centos/7"
BOX_VERSION = "1710.01"
ETCD_SERVER_COUNT = 3
NETWORK_ADAPTER_NAME = "Microsoft KM-TEST Loopback Adapter"

$etcdServerNamePrefix = "etcd"
$domainName = "example.com"
$ipGroup = "10.240.0"
$etcdServersStartIp = 10
$etcdServers = []
$etcdClusterConfig = ""

$hostsFileContent = ""

for i in 1..ETCD_SERVER_COUNT
$etcdServers << {
    name: "#{$etcdServerNamePrefix}#{i}",
    hostname: "#{$etcdServerNamePrefix}#{i}",
    ipAddress: "#{$ipGroup}.#{$etcdServersStartIp + i}"
}
end

for etcd in $etcdServers
    $hostsFileContent << etcd[:ipAddress] + " " + etcd[:hostname] + " " + etcd[:hostname] + "." + "#{$domainName}" + "\n"
    $etcdClusterConfig << "," + etcd[:hostname] + "=" + "https://" + etcd[:ipAddress] + ":2380"
end
$etcdClusterConfig = $etcdClusterConfig[1..-1]

$cmdInitialSetup = <<SCRIPT
yum -y update

service firewalld stop
systemctl disable firewalld
yum -y remove firewalld

cat <<EOF > /etc/selinux/config
SELINUX=disabled
SELINUXTYPE=targeted
EOF

cat <<EOF >> /etc/hosts
127.0.0.1    localhost.localdomain localhost
#{$hostsFileContent}
EOF
SCRIPT

$cmdEtcdCertificateSetup = <<SCRIPT
curl -Ls https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 -o cfssl_linux-amd64
chmod +x cfssl_linux-amd64
sudo mv cfssl_linux-amd64 /usr/local/bin/cfssl
ln -s /usr/local/bin/cfssl /usr/bin/cfssl

curl -Ls https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 -o cfssljson_linux-amd64
chmod +x cfssljson_linux-amd64
sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
ln -s /usr/local/bin/cfssljson /usr/bin/cfssljson

yes | cp /vagrant/ca-config.json .
yes | cp /vagrant/etcd-ca* .

cat > etcd-csr.json <<EOF
{
  "CN": "*.#{$domainName}",
  "hosts": [
    "%{hostname}",
    "%{hostname}.#{$domainName}",
    "%{ipAddress}",
    "localhost",
    "127.0.0.1"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "NO",
      "L": "Istanbul",
      "O": "Etcd",
      "OU": "Cluster",
      "ST": "Istanbul"
    }
  ]
}
EOF

cfssl gencert \
  -ca=etcd-ca.pem \
  -ca-key=etcd-ca-key.pem \
  -config=ca-config.json \
  -profile=etcd \
  etcd-csr.json | cfssljson -bare etcd
SCRIPT

$cmdEtcdSetup = <<SCRIPT
mkdir -p /etc/etcd/
mv etcd-ca.pem etcd-key.pem etcd.pem /etc/etcd/

curl -Ls https://github.com/coreos/etcd/releases/download/v3.2.10/etcd-v3.2.10-linux-amd64.tar.gz -o etcd-v3.2.10-linux-amd64.tar.gz
tar xzvf etcd-v3.2.10-linux-amd64.tar.gz
cp etcd-v3.2.10-linux-amd64/etcd* /usr/bin/
mkdir -p /var/lib/etcd

cat > etcd.service <<"EOF"
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/bin/etcd --name ETCD_NAME \
  --cert-file=/etc/etcd/etcd.pem \
  --key-file=/etc/etcd/etcd-key.pem \
  --peer-cert-file=/etc/etcd/etcd.pem \
  --peer-key-file=/etc/etcd/etcd-key.pem \
  --trusted-ca-file=/etc/etcd/etcd-ca.pem \
  --peer-trusted-ca-file=/etc/etcd/etcd-ca.pem \
  --initial-advertise-peer-urls https://INTERNAL_IP:2380 \
  --listen-peer-urls https://INTERNAL_IP:2380 \
  --listen-client-urls https://INTERNAL_IP:2379,http://127.0.0.1:2379 \
  --advertise-client-urls https://INTERNAL_IP:2379 \
  --initial-cluster-token etcd-cluster-0 \
  --initial-cluster #{$etcdClusterConfig} \
  --initial-cluster-state new \
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

export INTERNAL_IP='%{ipAddress}'
export ETCD_NAME=$(hostname -s)
sed -i s/INTERNAL_IP/$INTERNAL_IP/g etcd.service
sed -i s/ETCD_NAME/$ETCD_NAME/g etcd.service
mv etcd.service /etc/systemd/system/

systemctl daemon-reload
systemctl enable etcd
SCRIPT

$cmdReboot = <<SCRIPT
reboot
SCRIPT

Vagrant.configure("2") do |config|
  config.vm.provider "virtualbox"

  $etcdServers.each do |etcd|
    config.vm.define etcd[:name] do |box|
      box.vm.box = BOX_OS
      box.vm.box_version = BOX_VERSION
      box.vm.provider "virtualbox" do |v|
        v.memory = 512
        v.cpus = 1
      end
      box.vm.hostname = etcd[:hostname]
      box.vm.network "public_network", bridge: NETWORK_ADAPTER_NAME, ip: etcd[:ipAddress]
      box.vm.synced_folder ".", "/vagrant", disabled: false, type: "rsync", rsync__auto: true
      box.vm.provision "shell", inline: $cmdInitialSetup
      box.vm.provision "shell", inline: $cmdEtcdCertificateSetup % {hostname: etcd[:hostname], ipAddress: etcd[:ipAddress]}
      box.vm.provision "shell", inline: $cmdEtcdSetup % {ipAddress: etcd[:ipAddress]}
      box.vm.provision "shell", inline: $cmdReboot
    end
  end
end