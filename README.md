
hyperion-config-switch
======================

This script was created to allow an [Hyperion](https://github.com/tvdzwan/hyperion/) Ambilight configuration to be altered in reaction to external factors, such as a change in AVR power or input. This was something I desired to be able to do myself, but was also spurred on by requests for such features in the [Hyperion Issues forum](), specifically issues [#177](https://github.com/tvdzwan/hyperion/issues/177) and [#186](https://github.com/tvdzwan/hyperion/issues/186).

My own AVR is a network connected [Pioneer VSX-1028-K](www.pioneerelectronics.ca/POCEN/Home/AV-Receivers/FutureShop/VSX-1028-K). Upon investigation I found the AVR could be controlled using basic ASCII commands issued over a telnet connection. Not only that, but if a socket was left open, the AVR could be monitored through ASCII 'event' codes it writes for each behaviour.

### AVR Compatability

After learning this about my own AVR, I researched further and found almost-identical systems also employed by Denon and Onkyo, just with different event codes. If your AVR is network connected, you can easily tell if it is compatible using some basic steps.

Example codes for testing are listed below for known manufacturer specifications. Note however the specification files are old so just because your AVR is not listed does not mean it is not supported. Some specs have also changed over time so just because a manuf code doesn't work, doesn't mean it's not possible, you just need to find the correct codes.

- Replace `EVENT` in each of the following commands should be replaced with a compatible 'event' for your AVR manufacturer
- Replace `avr.ipa.ddr.ess` and `port` with values for your AVR


`printf "EVENT\r" | nc avr.ipa.ddr.ess port -w 1`

or

`{ echo "EVENT"; sleep 1; } | telnet avr.ipa.ddr.ess port`

Which will return a lot more, but in amongst it should be the same result

```
Trying xxx.xxx.xxx.xxx...
Connected to xxxxxxxxxxxx.local.
Escape character is '^]'.
EVENT
Connection closed by foreign host.
```

Using the latter telnet command, if you don't get anything the first time just try a couple more times. The telnet responses are inconsistent for some reason.

### Pioneer
Tested and working with Pioneer VSX-1028, but should work with all compatible series such as 82X, 102X, 112X and others compatible with IP commands as listed in [Pioneer Home Custom Install documentation]( http://www.pioneerelectronics.com/StaticFiles/PUSA/Files/Home%20Custom%20Install/VSX-1120-K-RS232.PDF). The included example configuration for Pioneer is based on this specification.

Compatability test event: `?P`.
Response: `PWR1` or `PWR0`, where 1 means is the AVR is powered off and 0 is on (backward I know).


### Denon
**Testers wanted**

The included example configuration for Denon is based on this specification.
http://openrb.com/wp-content/uploads/2012/02/AVR3312CI_AVR3312_PROTOCOL_V7.6.0.pdf

Compatability test event: `?PW`.
Response: `PWSTANDBY` or `PWON`.


### Onkyo
**Testers wanted**

The included example configuration for Onkyo is based on this specification.
http://www.epanorama.net/sff/Audio/Products/Receivers/Onkyo%20-%20TXDS989-rs232-codes%5B1%5D.pdf

Compatability test event: `?PWR`.
Response: `PWR00` or `PW01`, where 1 is on and 0 is off.


## Suggested Installation

Move your existing config file and creating a symbolic link as the file Hyperion will look for. This makes it easier to switch scripts without anything getting overwritten.

#### Raspbian / RaspBMC

SSH to your Pi, then complete the following steps:

```
cd
git clone https://github.com/Hwulex/hyperion-config-switch.git

cd hyperion-config-switch/
chmod a+x hyperion-config-switch.daemon.sh
sudo mv /etc/hyperion.config.json hyperion.config.default.json
ln -s hyperion.config.default.json hyperion.config.json
sudo ln -s hyperion.config.json /etc/hyperion.config.json
initctl restart hyperion
```
The final command may need to be run as `sudo /etc/init.d/hyperion restart`

At this point you will want to open the `hyperion-config-switch.conf` file in your favourite editor and put in your AVR IP address, port, etc, and make sure the Raspbmc paths are configured correctly. Then:
```
ln -s avr.YOUR_AVR_MANUFACTURER.conf avr.conf
./hyperion-config-switch.sh &
```

#### OpenELEC / RasPlex

SSH as **root** to your installation using `ssh root@box.ip.add.ress`. The default passwords are _openelec_ and _rasplex_ for the respective installs. Now complete the following steps

```
cd /storage/hyperion/config/
mv hyperion.config.json hyperion.config.default.json
ln -s hyperion.config.default.json hyperion.config.json

killall hyperiond
/storage/hyperion/bin/hyperiond.sh /storage/.config/hyperion.config.json </dev/null >/dev/null 2>&1 &

curl -L --output hyperion-config-switch.sh --get https://raw.githubusercontent.com/Hwulex/hyperion-config-switch/master/hyperion-config-switch.pioneer.sh
curl -L --output hyperion-config-switch.sh --get https://raw.githubusercontent.com/Hwulex/hyperion-config-switch/master/hyperion-config-switch.pioneer.conf
curl -L --output hyperion-config-switch.sh --get https://raw.githubusercontent.com/Hwulex/hyperion-config-switch/master/avr.YOUR_AVR_MANUFACTURER.conf
chmod a+x hyperion-config-switch.pioneer.sh
```
At this point you will want to open the `hyperion-config-switch.conf` file in your favourite editor and put in your AVR IP address, port, etc, and make sure the Raspbmc paths are configured correctly. Then:
```
ln -s avr.YOUR_AVR_MANUFACTURER.conf avr.conf
./hyperion-config-switch.sh &
```

## Per-Input Configuration

If you wish (or need) to run different Hyperion configurations for different AVR inputs (different black crops, colour casting, etc) then that is very easy. Simply copy the default hyperion.config.json file to another with the name of the corresponding AVR input code inserted. Next, ensure it is also listed in the `avr.MANUF.conf` file under `src_custom` and you're reading to go.

Example:
````
cp hyperion.config.json hyperion.config.FN20.json
````
Where FN20 is the HDMI2 input on my Pioneer AVR. Find the code for your input using the linked documents for your manufacturer and substitute in to these commands.

There is no need to restart the hyperion-config-switch.sh process. As long as the corresponding code was present in the avr.MANUF.conf src_custom section before loading, it will start using the file immediately.


## TODO

- [ ] Create a system-dependant install script for all this crap
- [ ] Document how to make script start at boot / with Hyperion
- [ ] Add notes about how to kill/restrt process
