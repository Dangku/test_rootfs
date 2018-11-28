#!/bin/sh

#source start_adb.sh
source script_parser.sh

display_type=`script_fetch "df_view" "display_type"`
echo "got display type is $display_type"
if [ $display_type -eq 1 ]; then
	echo "got hdmi display type"
	if [ -f /system/vendor/modules/hdmi.ko ]; then
		insmod /system/vendor/modules/hdmi.ko
	fi
else
	echo "got lcd display type"
fi

# insmod touchscreen driver
tp_module_path=`script_fetch "tp" "module_path"`
if [ -n "$tp_module_path" ]; then
    insmod "$tp_module_path"
	
	#traverse event num so that match tp event num and export it
	a=-1
	device_name=`script_fetch "tp" "device_name"`
	echo "script_fetch device name is $device_name"
	if [ -n "$device_name" ]; then								# match device name on a83 a64 platform
		for event in $(cd /sys/class/input; ls event*); do
			name=`cat /sys/class/input/$event/device/name`
			let a++
			case $name in
				$device_name)
					echo "Found tp device_name is $name"
					event_num=$a
					export TSLIB_TSDEVICE=/dev/input/event$event_num	# if match,export it for tp drvier
					;;
				*)
					;;
			esac
		done
	else
		# match event num on a33 platform
		event_num=`script_fetch "tp" "event_num"`
		export TSLIB_TSDEVICE=/dev/input/event$event_num
	fi
	
	# waiting for tp dev node
	found_time = 0
	 while true; do
		if [ ! -c /dev/input/event$event_num ]; then
			let found_time++
			if [ $found_time -eq 6 ];then
				echo "Time out,can not find tp event num /dev/input/event$event_num"
				break
			fi
			sleep 1
			continue
		else 
			echo "Found tp event num is /dev/input/event$event_num"
			# calibrate touchscreen if need
			tp_type=`script_fetch "tp" "type"`
			if [ $tp_type -eq 0 ]; then
				while true; do
					ts_calibrate
					if [ $? -eq 0 ]; then
						break
					fi
				done
			fi
			break
		fi
	done 
else
    echo "NO!!! touchscreen driver to be insmod"
fi


# insmod ir driver
ir_activated=`script_fetch "ir" "activated"`
if [ $ir_activated -eq 1 ]; then
    ir_module_path=`script_fetch "ir" "module_path"`
    if [ -n "$ir_module_path" ]; then
        insmod "$ir_module_path"
    fi
fi

# start camera test firstly
while true; do
    camera_activated=`script_fetch "camera" "activated"`
    echo "camera activated #$camera_activated"
    if [ $camera_activated -eq 1 ]; then
        echo "camera activated"
        module_count=`script_fetch "camera" "module_count"`
        if [ $module_count -gt 0 ]; then
            for i in $(seq $module_count); do
                key_name="module"$i"_path"
                module_path=`script_fetch "camera" "$key_name"`
                if [ -n "$module_path" ]; then
                    insmod "$module_path"
                    if [ $? -ne 0 ]; then
                        echo "insmod $module_path failed"
                        break 2
                    fi
                fi
            done
        fi
    else
        echo "camera not activated"
        break
    fi

    echo "camera module insmod done"
    touch /tmp/camera_insmod_done
done

# run dragonboard core process
core &
