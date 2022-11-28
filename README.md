

```
echo 'deb https://kadalu.tech/pkgs/1/ubuntu/22.04 /' | sudo tee /etc/apt/sources.list.d/kadalu.list
curl -fsSL https://kadalu.tech/pkgs/1/ubuntu/22.04/KEY.gpg | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/kadalu.gpg > /dev/null
```
