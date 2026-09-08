Custom 21.290.23.00.00 firmware and 17.100.19.01.00 web interface for E5372

The firmware is based on the original global firmware version 21.290.23.00.00. It can be installed on any previous firmware (unless you have locked bootloader), or updated from a modified firmware.
Flash through balongflash (https://github.com/forth32/balongflash/tree/master/winbuild/Release - Windows, https://github.com/forth32/balongflash/ - Linux).

Attention!
This firmware can render your device unbootable! Use it only if you are aware of all the risks and consequences. In case of any problems, do not wait for help, you're on your own. Do not install firmware by non-tech-savvy people request, and do not sell routers with this firmware preinstalled.

Why does the router shows "Not for resale, faggot!" text when turned on?
It is assumed that the firmware to be installed by tech-savvy people which would read its description to be aware of the risks associated with it, and would be able to modify the FW to their own needs, fix small bugs or at least update or revert to stock.
This firmware is mostly not for ordinary users, but for me and Huawei devices researchers.
The text "not for resale, fag!" was made in order to make selling the router with this firmware uncomfortable and embarrassing process. I do not want uninformed customers to receive a device with disabled security subsystems and no updates from the manufacturer.
Many may simply ignore "not for resale" phrase, but the expletive word makes you think it over and ask additional questions to the seller.

How to flash
To flash the router, you need to put it into firmware update (godload, go download) mode. This can be done in two equivalent ways:
1. Turn off the device, hold down the MENU button on top of the router and press the power button, press MENU again when "Force Download" appears;
2. Send the AT^GODLOAD command to the router's COM port

After switching the device to the firmware mode, unpack the firmware from the archive and run balong_flash, passing firmware file as an argument:
balong_flash FLASH_FILE.BIN

After flashing, send the AT^RESET AT command to the router's AT port, or reboot the device twice by holding the power button.

Changes:
* Firmware digital signature verification in the firmware server is disabled*
* Added support for IPv6 on mobile networks (disabled by default, could be activated "ipv6" script)**
* ADB installed and Telnet activated (disabled by default, controlled from the OLED menu)
* The stock versions of busybox, iptables and ip6tables programs are replaced with full-fledged ones ***
* The "atc" utility is installed to send AT commands from the console
* Installed "ttl" script for modifying (fixing) TTL (for IPv4) and HL (for IPv6)
* Installed "imei" script to change IMEI
* A local transparent proxy server "tpws" and a script "anticensorship" are installed to circumvent censorship to sites from the registry of prohibited sites in Russian Federation (IPv4 only)
* Added DNS over TLS resolver stubby (version 1.5.2, compiled with OpenSSL 1.0.2t) and DNS-level adblock (IPv4 only)
* Added extended menu on OLED screen https://github.com/ValdikSS/huawei_oled_hijack
* AT^DATALOCK code is disabled
* Added kernel module TUN/TAP (for OpenVPN and other programs)
* Added OpenVPN (version 2.4.8, compiled with OpenSSL 1.0.2t) and scripts for DNS redirection
* Added curl (version 7.67.0, compiled with OpenSSL 1.0.2t)
* Added EXT4 kernel module and swap support
* Added script for installing Entware application repository
* Added script "adblock_update", for updating the list of advertising domains
* Multilingual web interface with GSM/UMTS/LTE band selection menu

The extended menu on the LED screen allows you to manage network mode (LTE/3G/GSM), TTL modification, circumvent censorship, ad blocking, IMEI change, USB composition, control access to the web interface, Telnet and ADB.
TTL modification and IMEI change require a reboot. The remaining menu items are applied instantly.
To activate extended menu, press power button 7 times on Wi-Fi information screen.

Access to Telnet is performed with authentication: username root, password changemerightnow. Access to telnet is activated from the on-screen menu. You can change the password using the "passwd" command. Please change it immediately after flashing the firmware!
ADB is running by default, but access to it is disabled by the item in the LED menu.
Telnet can be completely disabled by creating the file /data/userdata/telnet_disable:

# touch /data/userdata/telnet_disable

Similarly, adbd is disabled:

# touch /data/userdata/adb_disable

The modification of TTL and HL, in addition to the menu on the OLED screen, is controlled by the "ttl" script. Call it with the TTL and HL value you want to install for outgoing packets. For example:

# ttl 64

The TTL and HL modification script is compatible with the existing management scripts for the computer https://4pda.ru/forum/index.php?act=findpost&pid=51716190&anchor=Spoil-51716190-19.

The "anticensorship" script helps to bypass Deep Packet Inspection (DPI) systems on some operators in order to bypass web site blocking. It starts the local proxy server from zapret complex https://github.com/bol-van/zapret, modifying the packets in such a way as to complicate their analysis, and redirects all traffic to ports 80 (for HTTP) and 443 (for HTTPS) to local proxy. The proxy server works autonomously, without any third-party server on the Internet. It is recommended to use it in conjunction with DNS over TLS, in order to prevent possible DNS hijacking by the operator.

Advertisement blocking is performed on DNS level with dnsmasq DNS server. It works with DNS over TLS as upstream, requests for which are redirected if the corresponding menu item is activated from the OLED screen. List of advertisement is provided by shakal: https://4pda.ru/forum/index.php?s=&showtopic=275091&view=findpost&p=89665467
Ad-blocking at the DNS level works worse than full-fledged content blockers in browsers (AdBlock, µBlock), but it works on any device and in any program without additional settings.
You can also control ad blocking with the "dns_over_tls" script.
Domain lists could be updated using "adblock_update" command.

Entware application repository allows you to install additional Linux software from the armv7sf-k2.6 entware repository http://bin.entware.net/armv7sf-k2.6/Packages.html, using "opkg" package manager used in open source firmware for OpenWRT routers. Entware is installed using the "entware install" command. Entware files are installed in /opt, which is mounted in /online/opt. You can install many programs on 30 MB free space after installation on /online partition.
The router and Entware environments are independent of each other, the installed Entware software cannot be called from the router's environment, and the firmware programs and scripts cannot be called from the Entware. This was done to ensure that the installed packages would not conflict with files in the firmware.
To gain access to the Entware environment, use the "entware shell" command, to exit, type exit (or press CTRL+D).
Entware is designed for advanced users who understand how to customize and use installable programs. About 15 MB of free RAM is available in the router, the launch of heavy programs can lead to the crash of important services for the router (especially when DNS over TLS is enabled), remember that

* but the signature, albeit incorrect, must be present.
** IPv6 could be enabled with 'ipv6' script. IPv6 PDP support is not enabled by default due to the strange performance of some mobile operators that do not support IPv6 (in particular, Yota is constantly reconnecting to the network). The "anticensorship" and "dns_over_tls" scripts do not fully support IPv6, when they are activated, DNS requests from the router to the Internet using the IPv6 protocol are blocked (but the resolution from the devices connected to the router via the router's DNS server will still work on IPv6).
*** full iptables is called by the xtables_multi command.

ValdikSS, iam@valdikss.org.ru
https://github.com/Huawei-LTE-routers-mods/
