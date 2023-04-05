

```
echo 'deb https://kadalu.tech/pkgs/1.1.x/ubuntu/22.04 /' | sudo tee /etc/apt/sources.list.d/kadalu.list
curl -fsSL https://kadalu.tech/pkgs/1.1.x/ubuntu/22.04/KEY.gpg | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/kadalu.gpg > /dev/null
sudo apt update
```

Install Kadalu Storage and NFS Ganesha plugin

```
sudo apt install kadalu-storage nfs-ganesha-kadalu
```
