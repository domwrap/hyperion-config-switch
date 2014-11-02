#! /bin/bash
# Script to switch configuration files and to 
# turn Hyperion LEDs on and off dependent on
# state of Pioneer Network AVR (eg VSX102X series)
# Author: Dominic Wrapson <hwulex@gmail.com>
# License: The MIT License (MIT)
# http://choosealicense.com/licenses/mit/


##############################################
# Here be where you config yo stuff
##############################################
#
#OpenElec/RasPlex
#path_remote="/storage/hyperion/bin/hyperion-remote.sh"
#path_config="/storage/hyperion/config/"
#path_reload="killall hyperiond; /storage/hyperion/bin/hyperiond.sh /storage/.config/hyperion.config.json </dev/null >/dev/null 2>&1 &"
# Raspbian
#path_remote="hyperion-remote"
#path_config="/home/pi/hyperion-config-switch"
#path_reload="initctl restart hyperion"
#
path_remote="/storage/hyperion/bin/hyperion-remote.sh"
# path_config MUST END IN A TRAILING SLASH! As I'm too lazy to detect and do anything about it if not
path_config="/storage/hyperion/config/"
path_reload="killall hyperiond; /storage/hyperion/bin/hyperiond.sh ${path_config}hyperion.config.json </dev/null >/dev/null 2>&1 &"


# Visual effects for power-on and power-off
# Leave blank for none
on_effect="Rainbow swirl fast"
on_duration=3000
off_effect="Knight rider"
off_duration=2500

# Config file, so we can save previous state of AVR
# If exists, should contain key=value pairs
# POWER=1 (or 0) which is actually inverted to what you might expect
# INPUT=19FN (etc)
config="/tmp/hyperion-config-switch.cfg"
log="/tmp/hyperion-config-switch.log"
#
##############################################




# Query current power state of AVR
avr_power=`printf "?P\r" | nc -w 1 10.0.0.119 23 | head -c4`
# Pioneer states minimum 100ms between power on and subsequent requests
sleep 0.2
# Query current input for AVR
avr_input=`printf "?F\r" | nc -w 1 10.0.0.119 23 | head -c4`
# Pull in config-saved previous state of AVR. Supress output in case doesn't already exist
if [ -e $config ]
then
	echo Config file found, reading
	source $config &> /dev/null
else
	echo Config file not found, creating
	echo POWER=$avr_power | sed s/PWR// > $config
	echo INPUT=$avr_input >> $config
fi
# Remote durations are in miliseconds but bash sleeps in seconds so do some conversion
off_sleep=$(((off_duration+1000)/1000))
on_sleep=$(((on_duration+1000)/1000))

# Some debug stuff, can ignore
#echo $avr_power
#echo \n
#echo $avr_input

# Switch dependant on reult of power-query
case "$avr_power" in

	# power is off
	"PWR1")
		# Visual effect, if wanted, to confirm power off
		# Remember 1 is off, 0 is on
		if [ "0" = "$POWER" ] && [ -n "$path_remote" ]
		then
			echo AVR powered off: $off_effect
			$path_remote --effect "$off_effect" --duration $off_duration #>> $log 2>&1
			sleep $off_sleep
		fi

		# Sending black at a low channel (zero) effectively switching off leds
		# suggestion from tvdzwan (https://github.com/tvdzwan/hyperion/issues/177#issuecomment-58793948)
		$path_remote --priority 0 --color black #>> $log 2>&1

		# Save (backward) power state to config file
		echo POWER=1 > $config
		echo INPUT=$avr_input >> $config
		;;

	# power is on!
	"PWR0")
		# Remove the channel block by clearing selected channel
		# Again suggested by tvdzwan, see above for link
		$path_remote --priority 0 --clear #>> $log 2>&1

		# Trigger an effect here, if you like, as visual confirmation  we're back
		# Remember 1 is off, 0 is on
                if [ "1" = "$POWER" ] && [ -n "$path_remote" ]
		then
			echo AVR powered on: $on_effect
			$path_remote --effect "$on_effect" --duration $on_duration #>> $log 2>&1
			sleep $on_sleep
                fi

		# Read previous input of amp from last query and see if changed, otherwise don't bother
		if [ "$avr_input" != "$INPUT" ]
		then

			# Use a cascading switch, pipe separated to flip input-specific config file
			# Add as many different inputs here as you wish, separated by a pipe "|"
			# and just make sure the line ends with a closing bracket ")"
			# e.g.
			# "FN19" | "FN20" | "FN15")
			#
			# Full list of input codes provided by Pioneer
			# http://www.pioneerelectronics.com/StaticFiles/PUSA/Files/Home%20Custom%20Install/VSX-1120-K-RS232.PDF
			case "$avr_input" in

				# Input specific config file: What each of these correspond to can be found on the github readme/wiki
				"FN05" | "FN01" | "FN03" | "FN04" | "FN19" | "FN05" | "FN00" | "FN03" | "FN26" | "FN15" | "FN05" | "FN10" | "FN14" | "FN19" | "FN20" | "FN21" | "FN22" | "FN23" | "FN24" | "FN25" | "FN17")
					# My config
					# FN19: Chromecast (HDMI1)
					# FN20: Plex (HDMI2)

					# Check to see if a valid config file for switched input actually exists
					if [ -e ${path_config}hyperion.config.${avr_input}.json ]
					then
						# Change config file to input-specific one
						echo Switching to $avr_input config file
						new_config="${path_config}hyperion.config.$avr_input.json"
					else
						# Input is setup but config file is not found, default it
						echo Config file not found, switching to default
						new_config="${path_config}hyperion.config.default.json"
					fi
					;;

				# Default config
				*)
					# Set config to default file
					echo Switching to default config file
					new_config="${path_config}hyperion.config.default.json"
					;;

			esac

			# Check to see if the config file will actually be changing
			current_config=`ls -l $path_config | awk '{print $11}'`
			if [ $current_config != $new_config ]
			then
				# Force the config change upon Hyperion
				change_config="ln -s ${new_config} ${path_config}hyperion.config.json -f"
				eval $change_config
				echo Config file switched, restarting Hyperion
				eval $path_reload
			else
				echo Requested config file already in use, leaving as is
			fi
		fi

		# Save (backward) power state to config file
		echo POWER=0 > $config
		echo INPUT=$avr_input >> $config

		;;
	*)
	# Invalid option, query or result must have failed
		echo Invalid option, power detection failed. Exiting
		;;
esac
