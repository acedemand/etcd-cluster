echo '{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "etcd": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}' > ca-config.json

echo '{
  "CN": "Etcd",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "NO",
      "L": "Istanbul",
      "O": "Etcd",
      "OU": "CA",
      "ST": "Istanbul"
    }
  ]
}' > etcd-ca-csr.json

cfssl gencert -initca etcd-ca-csr.json | cfssljson -bare etcd-ca
