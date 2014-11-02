# WORK IN PROGRESS #
These instructions are currently incomplete

hyperion-config-switch
======================

Scripts to switch Hyperion Ambilight config files based on external factors, such as a change in AVR power or input.

### Pioneer

Initially just have config switching script for Pioneer network AVR series such as 82X, 102X, 112X and others compatible with IP commands as listed in [Pioneer Home Custom Install documentation]( http://www.pioneerelectronics.com/StaticFiles/PUSA/Files/Home%20Custom%20Install/VSX-1120-K-RS232.PDF)

**NOTE:** The Pioneer file is old so just because your AVR is not listed does not mean it is not supported. It is easy to test if you know the IP address of your AVR:

`printf "?P\r" | nc xxx.xxx.xxx.xxx 23 -w 1`

Which should return either `PWR1` or `PWR0`, where 1 means is the AVR is powered off and 0 is on (backward I know).

If that doesn't return a result, try this instead

`{ echo "?F"; sleep 1; } | telnet xxx.xxx.xxx.xxx 23`

Which will return a lot more, but in amongst it should be the same result

```
Trying xxx.xxx.xxx.xxx...
Connected to xxxxxxxxxxxx.local.
Escape character is '^]'.
PWR1
Connection closed by foreign host.
```

Using the latter telnet command, if you don't get anything the first time just try a couple more times. The telnet responses are inconsistent for some reason.


## Suggested Installation

Move your existing config file and creating a symbolic link as the file Hyperion will look for. This makes it easier to switch scripts without anything getting overwritten.


#### Raspbmc

SSH to your Pi, then complete the following steps:

```
cd
mkdir hyperion-config-switch
cd hyperion-config-switch/
sudo mv /etc/hyperion.config.json hyperion.config.default.json
ln -s hyperion.config.json hyperion.config.default.json
ln -s /etc/hyperion.config.json hyperion.config.json

initctl restart hyperion

wget https://raw.githubusercontent.com/Hwulex/hyperion-config-switch/master/hyperion-config-switch.pioneer.sh

#### INSERT CRON INSTRUCTIONS ####
```

#### OpenELEC / RasPlex

SSH as **root** to your installation using `ssh root@box.ip.add.ress`. The default passwords are _openelec_ and _rasplex_ for the respective installs. Now complete the following steps

```
cd /storage/hyperion/config/
mv hyperion.config.json hyperion.config.default.json
ln -s hyperion.config.json hyperion.config.default.json

killall hyperiond
/storage/hyperion/bin/hyperiond.sh /storage/.config/hyperion.config.json </dev/null >/dev/null 2>&1 &

curl -L --output hyperion-config-switch.sh --get https://raw.githubusercontent.com/Hwulex/hyperion-config-switch/master/hyperion-config-switch.pioneer.sh

#### INSERT CRON INSTRUCTIONS ####
```


## TODO

Create a system-dependant install script for all this crap
