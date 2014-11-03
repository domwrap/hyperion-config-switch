#! /bin/bash
# Script to switch configuration files and to 
# turn Hyperion LEDs on and off dependent on
# state of Pioneer Network AVR (eg VSX102X series)
# Author: Dominic Wrapson <hwulex@gmail.com>
# License: The MIT License (MIT)
# http://choosealicense.com/licenses/mit/


#####################################################
#		Here be where you config yo stuff			#
#####################################################
#
#
# IP address or hostname of AVR
avr_ip="xxx.xxx.xxx.xxx"
# avr_port="23"
avr_port="8102"
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


# Visual effect for power-off
# Leave blank for none
off_effect="Knight rider"
off_duration=2500

# Config file, so we can save previous state of AVR
# If exists, should contain key=value pairs
# POWER=1 (or 0) which is actually inverted to what you might expect
# INPUT=19FN (etc)
config="/tmp/hyperion-config-switch.cfg"
log="/var/log/hyperion-config-switch.log"
#
#
#
#
#####################################################
#	END OF USER DEFINED SETTINGS, LEAVE THE REST 	#
#####################################################




# Remote durations are in miliseconds but bash sleeps in seconds so do some conversion
off_sleep=$(((off_duration+1000)/1000))
on_sleep=$(((on_duration+1000)/1000))

{
	echo "[$(date "+%F %T")] Starting loop"

	while :
	do
		echo "[$(date "+%F %T")] Starting netcat"

		nc $avr_ip $avr_port | while read line
		do
            match=$(echo "$line" | grep -c '^FN\|PWR')
			if [ "$match" -eq 1 ]; then
				# clean the input
				line=${line//[^a-zA-Z0-9]/}

				# Pull in config-saved previous state of AVR. Supress output in case doesn't already exist
				if [ ! -e $config ]
				then
					echo "[$(date "+%F %T")] Settings file not found, creating"
					echo "POWER=1" > $config
					echo "INPUT=FN00" >> $config
				fi
				echo "[$(date "+%F %T")] Reading settings file"
				source $config &> /dev/null
				echo "[$(date "+%F %T")] Setting INPUT=$INPUT"
				echo "[$(date "+%F %T")] Setting POWER=$POWER"

				# Switch dependant on reult of power-query
				case "${line:0:2}:$line" in
				# case "$(echo $line|head -c2)" in

					# power is off
					"PW":"PWR1")
						echo "[$(date "+%F %T")] Power state changed: $line"

						# Visual effect, if wanted, to confirm power off
						# Remember 1 is off, 0 is on
						if [ "0" = "$POWER" ] && [ -n "$path_remote" ]
						then
							echo "[$(date "+%F %T")] AVR powered off: $off_effect"
							`${path_remote} --effect "${off_effect}" --duration ${off_duration} &`
							sleep $off_sleep
						fi

						# Sending black at a low channel (zero) effectively switching off leds
						# suggestion from tvdzwan (https://github.com/tvdzwan/hyperion/issues/177#issuecomment-58793948)
						eval "$path_remote --priority 0 --color black"

						# Save (backward) power state to config file
						echo POWER=1 > $config
						echo INPUT=$INPUT >> $config
						;;

					# power is on!
					"PW":"PWR0")
						echo "[$(date "+%F %T")] Power state changed: $line"

						# Remove the channel block by clearing selected channel
						# Again suggested by tvdzwan, see above for link
						eval "$path_remote --priority 0 --clear"

						# Trigger an effect here, if you like, as visual confirmation  we're back
						# Remember 1 is off, 0 is on
						if [ "1" = "$POWER" ] && [ -n "$path_remote" ]
						then
							echo "[$(date "+%F %T")] AVR powered on: config-file on-effect will show"
							eval $path_reload
							sleep $on_sleep
						fi

						# Save (backward) power state to config file
						echo POWER=0 > $config
						echo INPUT=$INPUT >> $config
						;;

					# Invalid option, query or result must have failed
					"PW":*)
						echo "[$(date "+%F %T")] Power detection failed. Invalid option: $line"
						;;

					# Input specific config file: What each of these correspond to can be found on the github readme/wiki
					# Use a cascading switch, pipe separated to flip input-specific config file
					# Add as many different inputs here as you wish, separated by a pipe "|"
					# and just make sure the line ends with a closing bracket ")"
					# e.g.
					# "FN19" | "FN20" | "FN15")
					#
					# Full list of input codes provided by Pioneer
					# http://www.pioneerelectronics.com/StaticFiles/PUSA/Files/Home%20Custom%20Install/VSX-1120-K-RS232.PDF
					"FN":*)

						# Read previous input of amp from last query and see if changed, otherwise don't bother
						if [ "$line" != "$INPUT" ]
						then
							echo "[$(date "+%F %T")] Input changed: $line"

							case "$line" in
								"FN00"|"FN01"|"FN03"|"FN04"|"FN05"|"FN10"|"FN14"|"FN15"|"FN17"|"FN19"|"FN20"|"FN21"|"FN22"|"FN23"|"FN24"|"FN25"|"FN26")

									# Check to see if a valid config file for switched input actually exists
									if [ -e "${path_config}hyperion.config.${line}.json" ]
									then
										# Change config file to input-specific one
										echo "[$(date "+%F %T")] Switching to $line config file"
										new_config="${path_config}hyperion.config.$line.json"
									else
										# Input is setup but config file is not found, default it
										echo "[$(date "+%F %T")] Input specific config file not found, switching to default"
										new_config="${path_config}hyperion.config.default.json"
									fi

									;;
							esac
							# ;;

							# Set config to default file, if not already set
							if [ -z "$new_config" ]; then
								echo "[$(date "+%F %T")] Switching to default config file"
								new_config="${path_config}hyperion.config.default.json"
							fi

							# Check to see if the config file will actually be changing
							current_config=`ls -l $path_config | awk '{print $11}' | awk 1 ORS=''`
							if [ "$current_config" != "$new_config" ]
							then
								# Force the config change upon Hyperion
								eval "ln -s ${new_config} ${path_config}hyperion.config.json -f"
								echo "[$(date "+%F %T")] Config file switched, restarting Hyperion"
								eval $path_reload
							else
								echo "[$(date "+%F %T")] Requested config file already in use, leaving as is"
							fi
						fi

						# Write current input to config for next check
						echo POWER=$POWER > $config
						echo INPUT=$line >> $config
						;;

					# Nothing matched, somehow something unrecognised slipped through
					*:*)
						echo "[$(date "+%F %T")] Bad request, unsupported AVR code: $line"
						;;

				esac

			fi
		done

		echo "[$(date "+%F %T")] Netcat has stopped or crashed"

		sleep 4s
	done
} >> $log 2>&1
