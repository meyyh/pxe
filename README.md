# how to pxe boot windows and linux with UEFI support
software used is 
> pm = package manager apt, pacman, or dnf etc
- ipxe - pm or https://boot.ipxe.org/ipxe.iso
- dnsmasq - pm
- nginx - pm (any http server will work)
- wimboot - https://github.com/ipxe/wimboot/releases/latest/download/wimboot
- winpe - download winpe add on for windows adk from microsoft website
## important/notes
- no 32 bit or ipv6 support (both can be added I just did not need them)
- I used debian but any linux distro will work
- make sure you allow ports 67, 68, and 80 through the firewall if there is one
- dnsmasq will become the dhcp server for your network
- a windows pc is required to get winpe files but everything is run off of linux
- netowrk is 172.16.0.0/16 with the pxe servers ip being 172.16.0.40
## 1. setup ipxe
1. in linux install ipxe dnsmasq wimboot and nginx  

   ```
   apt install ipxe dnsmasq nginx wget && wget https://github.com/ipxe/wimboot/releases/latest/download/wimboot
   ```
2. copy the dnsmasq.conf file and paste it into /etc/dnsmasq.conf and edit
   - the interface
   - dhcp ranges gateway and dns
   - tftp directory

3. make ipxe menu
   ```
   mkdir -p /tftp/menu && touch /tftp/menu/menu.ipxe
   ```
   copy the menu.ipxe file in this repo into /tftp/menu/menu.ipxe
4. setup nginx
    ```
    mkdir /srv/http
    ```
    edit the /etc/nginx/sites-enabled/default file so it looks something like this
    ```
    ...
    server {
      ...
      root /srv/http
      ...
      location / {
            autoindex on;
      }
    }
5. enable services
   ```
   systemctl enable nginx && systemctl start nginx && systemctl enable dnsmasq && systemctl start dnsmasq\
   ```
## 2. get winpe files
1. on a windows pc go to [ms adk install page](https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install) and download the winpe add on for adk (you dont need the full adk)
2. after install go to ``` C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment ```
   and replace the copype.cmd script with the one in this repo (originally found [here](https://superuser.com/questions/1333698/how-to-run-copype-cmd-for-winpe-from-batch-file))
3. run the command
   ```
   .\copype.cmd amd64 C:\winpe
   ```
4. copy the entire C:\winpe folder to /srv/http/winpe
   
   

