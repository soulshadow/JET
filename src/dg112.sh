#!/bin/sh

#  dg112.sh - yarrimapirate@XDA, SouL Shadow@XDA
#  
#  A script to automate the force QDL process for downgrading HBoot to 1.12
#  on the HTC EVO 4G LTE.

#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.


#########################
#  ===  Variables  ===  #
#########################

version="0.2.1beta"
logfile="logfile.txt"   # Unset to disable logging.  NOT RECOMMENDED
verbose=1               # Interactive, On by default
superCID=1				# Apply SuperCID mod during downgrade, On by default

#################################
#  ===  Utility Functions  ===  #
#################################

PrintScreen() {         # Print to screen, if enabled.
        if [ $verbose=1 ] ; then
	        printf "$1"
	fi
}


PrintLog() {            # Print to log file, if enabled.
        if [ $logfile ] ; then
	        printf "$1" >> $logfile
	fi
}


PrintBoth() {           # Print to screen and log
	PrintScreen "$1"
	PrintLog "$1"
}


GetYN() {
	while true;
	do
		PrintScreen "[Y]es or [N]o?"
		read FINAL
		case $FINAL in
			y | Y | yes | Yes) break;;
			n | N | no | No) exit;;
		esac
	done
}


###############################
#  ===  Setup Functions  ===  #
###############################


InitDG112() {
        #  Logging
	if [ ! -e $logfile ]; then
	        if ! touch $logfile ; then 
		        printf "FATAL:  Unable to create file \'$logfile\'\n\n"
			exit 1;
		fi
	fi
	PrintLog "HTC EVO 4G LTE HBOOT Downgrade Tool v$version\n"
	PrintLog "$(date)\n"
	PrintLog "$(uname -a)\n"

	#  Check for Root
	if [ "$(whoami)" != 'root' ]; then
			PrintBoth "$0 requires root.  (sudo $0)\n"
			exit 1;
	fi

	#  Check for required files
	if [ ! -e "./killp4" ]; then
		PrintBoth  "FATAL:  File killp4 missing.\n\n"
		exit 1
	fi

	if [ ! -e "./blankp4" ]; then
		PrintBoth  "FATAL:  File blankp4 missing.\n\n"
		exit 1
	fi

	if [ ! -e "./hboot_1.12.0000_signedbyaa.nb0" ]; then
		PrintBoth  "FATAL:  File hboot_1.12.0000_signedbyaa.nb0 missing.\n\n"
		exit 1
	fi

	if [ ! -e "./emmc_recover" ]; then
		PrintBoth  "FATAL:  File \'emmc_recover\' missing.\n\n"
		exit 1
	fi

	if [ ! -e "./adb" ]; then
		PrintBoth  "FATAL:  File \'adb\' missing.\n\n"
		exit 1
	fi

	if [ ! -e "./fastboot" ]; then
		PrintBoth  "FATAL:  File \'fastboot\' missing.\n\n"
		exit 1
	fi

        if [ ! -x "./adb" ]; then
	        chmod +x ./adb
	fi
	
	if [ ! -x "./fastboot" ]; then
        	chmod +x ./fastboot 
	fi
	
	if [ ! -x "./emmc_recover" ]; then
        	chmod +x ./emmc_recover
	fi
}


#############################
#  ===  QDL Functions  ===  #
#############################


WakeQDL() {			#Spam pbl_reset until the phone responds
        PrintLog "In WakeQDL()\n"
        count=1
	wakeresult=`./emmc_recover -r | tail -1`
        while [ "$wakeresult" = "Cannot reset device" ]
	do 
		wakeresult=`./emmc_recover -r | tail -1`
		count=$(($count+1))
	done 
	PrintBoth "Took $count tries...\n"
	PrintLog "Exiting WakeQDL()\n"
}


PrepQDL() {
        PrintLog "In PrepQDL()\n"
        PrintBoth  "Resetting qcserial module...\n"
        modprobe -r qcserial					# Reset qcserial kernel module and clear old blocks
        sleep 1
        PrintBoth  "Creating block device...\n"
        mknod /dev/ttyUSB0 c 188 0				# Create block device for emmc_recover
        PrintBoth  "Waking QDL device...\n"
        WakeQDL
        sleep 2
        PrintLog "Exiting PrepQDL()\n"
}


CheckBrick() {				# QDL device detection
        PrintLog "In CheckBrick()\n"
	lastdrive=$(ls -r /dev/sd? | sed 's\/dev/sd\\' | dd bs=1 count=1 2> /dev/null)	# Get all current /dev/sd* and filter to single letter of last drive
	ldascii=$(printf '%d\n' "'$lastdrive")											# Convert letter to ASCII value
	bdascii=$((ldascii+1))															# Increment ASCII Value, store in new variable
	brickdrive=$(printf \\$(printf '%03o' $bdascii))								# Convert brick drive ASCII value to character, store for later use
	PrintLog "Device connected at: $brickdrive\n"
#   Needs Work - disabled for now

#	printf  "\nDetecting bricked device...  "
#
#	sleep 3
#	qcserialstate=`dmesg | grep 'qcserial' | tail -1 | awk '{print $NF}'`
#	if [ "$qcserialstate" != "detected" ] -a [ "$qcserialstate" != "qcserial" ]; then
#		printf  "\n\nCannot detect bricked phone.  Please check your USB connection.\n\n"
#		read -p "Press Enter to retry detection..." p
#		modprobe -r qcserial
#		CheckBrick
#	fi
#	printf  "Found it!\n\n"
        PrintLog "Exiting CheckBrick()\n"
}


####################################
#  ===  HBoot Flash Function  ===  #
####################################


Flash112() {
        PrintLog "In Flash112()\n"
	flashresult=""

	PrintBoth  "Now flashing the 1.12 bootloader.\n\n"
	if [ $verbose ]; then
		PrintScreen  "\nFrom here forward, DO NOT UNPLUG THE PHONE FROM THE USB CABLE!\n\n"
		PrintScreen  "If this process hangs at \"Waiting for /dev/sd"$brickdrive"12...\"  Press and\n"
		PrintScreen  "hold the power button on your phone for no less than 30 seconds and\n"
		PrintScreen  "then release it.  The process should wake back up a few seconds afterwards.\n\n"
		PrintScreen  "Note that this process can take as long as 10 minutes to complete and you\n"
		PrintScreen  "will see a lot of repetitive output from the recovery tool.\n\n"
		PrintScreen  "If this process fails to complete, your bricked phone should be\n"
		PrintScreen  "accessible at /dev/sd$brickdrive\n\n"
	fi

	while [ "$flashresult" != "Detected mode-switch" ]
	do
		PrepQDL
		./emmc_recover -q -f hboot_1.12.0000_signedbyaa.nb0 -d /dev/sd"$brickdrive"12 -c 24576 | tee ./result	# Flash Signed 1.12 HBoot
		flashresult=`cat ./result| tail -1`
		rm ./result
		if [ "$flashresult" != "Detected mode-switch" ]; then
			PrintBoth "Error flashing HBOOT 1.12!\n\n"
			sleep 2
			PrintBoth "Retrying...\n\n"
		fi
	done
	PrintLog "Exiting Flash112()\n"
}


###################################
#  ===  mmcblk0p4 Functions  ===  #
###################################


BackupP4() {
        PrintLog "In BackupP4()\n"
	if [ $superCID = 0 ]; then
		PrintBoth "**SuperCID mode is OFF**\n"
	fi
	PrintBoth "Backing up mmcblk0p4 to /sdcard/bak4\n"
	PrintBoth  "Rebooting to bootloader...\n\n"

	./adb reboot bootloader

	PrintBoth  "Getting IMEI value...\n\n"

	sleep 2
	./fastboot getvar imei 2>&1 | grep "imei:" | sed s/"imei: "// > imei.txt	# Get IMEI from phone and store

	PrintBoth  "Building failsafe P4 file...\n\n"

	dd if=blankp4 bs=540 count=1 > ./fsp4 2> /dev/null		# First part of our failsafe P4 file
	dd if=imei.txt bs=15 count=1 >> ./fsp4 2> /dev/null		# Add IMEI
	dd if=blankp4 bs=555 skip=1 >> ./fsp4 2> /dev/null		# Last part

	rm imei.txt												# Cleanup

	s=$(stat -c %s "./fsp4")								# Get size of fsp4  (Should be exactly 1024 bytes)
	if [ $s != 1024 ]; then									# Stop if size isn't right
		PrintBoth  "FATAL:  Failsafe P4 size mismatch.\n"
		exit 1
	fi

	PrintBoth  "Success.  Rebooting phone.\n\n"

	./fastboot reboot 2> /dev/null
	./adb wait-for-device

	PrintBoth  "Rebooting to recovery...\n\n"

	./adb reboot recovery

	PrintBoth  "Waiting 45s for recovery...\n\n"

	sleep 45


	PrintBoth  "Pulling /dev/block/mmcblk0p4 backup from phone...\n\n"

	./adb shell dd if=/dev/block/mmcblk0p4 of=/sdcard/bakp4 > /dev/null		#  Copy P4 data to internal storage

	#  Redundant since we check for local bakp4 before continuing.  Save for --recover option

	#sdstatus=`./adb shell "if [ -e /sdcard/bakp4 ]; then  echo 1; fi`		#  Check for successful file creation on internal storage
	#if [ "$sdstatus" != "1" ]; then
	#	printf  "FATAL:  Failure to create mmcblk0p4 backup on internal storage (/sdcard).\n\n"
	#	exit 1
	#fi
	# 
	#
	#./adb shell dd if=/dev/block/mmcblk0p4 of=/sdcard2/bakp4 > /dev/null  				#  Copy P4 data to external storage
	#
	#sdstatus=`./adb shell "if [ -e /sdcard2/bakp4 ]; then  echo 1; fi`				#  Check that SD Card Backup was made
	#if [ "$sdstatus" != "1" ]; then
	#	printf  "WARNING: A backup of your Partition 4 was not made on the SD Card.\n"
	#	printf  "Is an SD Card in your phone? Is it full?\n"
	#	printf  "It's recommended that a backup is made on an SD Card.\n\n"
	#	printf  "You can continue without making a backup, but it's a good idea.\n"
	#	
	#	SDBackup(){
	#	printf  "Continue without SD Card backup?"
	#	GetYN
	#	}
	#
	#rm sdstatus

	./adb pull /sdcard/bakp4 ./bakp4  2> /dev/null							#  Pull file from internal storage to local machine

	if [ ! -e ./bakp4 ]; then	
      	PrintBoth  "FATAL:  Backup mmcblk0p4 creation failed.\n\n"
		exit 1
	fi
	
	if [ $superCID = 1 ]; then
		PrintBoth  "Applying SuperCID mod to backup P4.\n\n"
		echo 11111111 > supercid.txt
		cidresult=`dd if=supercid.txt seek=532 bs=1 count=8 of=./bakp4 conv=notrunc 2>&1`
		PrintLog  "$cidresult"
		rm supercid.txt
	fi

	s=0
	s=$(stat -c %s ./bakp4)									#  Get size of bakp4  (Should be exactly 1024 bytes)
	if [ $s != 1024 ]; then									#  Stop if size isn't right
		PrintBoth  "FATAL:  Backup mmcblk0p4, size mismatch on local disk.\n\n"
		exit 1
	fi

	PrintBoth  "\nSuccess.\n\n\n"
	PrintLog "Exiting BackupP4()\n"
}


KillP4() {
        PrintLog "In KillP4()\n"
	./adb push ./killp4 /sdcard > /dev/null					# Load corrupt p4 file onto internal storage

	#loadedkill = `./adb shell "if [ -e /sdcard/killp4 ]; then echo 1; fi"`
	#if [ $loadedkill != 1 ]; then
	#	printf  "FATAL:  Unable to load corrupt mmcblk0p4 file onto internal storage.\n\n"
	#	exit 1
	#fi

	./adb shell "dd if=/sdcard/killp4 of=/dev/block/mmcblk0p4" > /dev/null		# Flash corrupt p4 file
	./adb shell "rm /sdcard/killp4"	 > /dev/null								# Clean up

	PrintBoth  "Rebooting...\n\n"

	sleep 2
	./adb reboot													# Complete force QDL
        PrintLog "Exiting KillP4()\n"
}


FlashBakP4() {
        PrintLog "In FlashBakP4()\n"
	flashresult=""
	while [ "$flashresult" != "Okay" ]
	do
		PrepQDL
		PrintBoth "Restoring /dev/block/mmcblk0p4...\n\n"
		flashresult=`./emmc_recover -q -f ./bakp4 -d /dev/sd"$brickdrive"4 | tail -1`	# Flash backup p4 file
		if [ "$flashresult" != "Okay" ]; then
			PrintBoth "Error restoring P4 partition!\n\n"
			sleep 2
			PrintBoth "Retrying...\n\n"
		fi
	done
	PrintBoth  "\n\nSuccess!\n\n"
	PrintScreen  "Your phone should reboot in a few seconds.  If yours doesn't, simply unplug \n"
	PrintScreen  "the USB cable and hold your power button for a few seconds.\n\n"
        PrintLog "Exiting FlashBakP4()\n"
}


BackupOnly() {
    PrintBoth "**Backup Only Mode**\n\n"

	PrintBoth  "\nPreparing...\n"

	sleep 2
	./adb kill-server > /dev/null
	./adb start-server > /dev/null

	BackupP4
	./adb reboot
	PrintBoth "Done\n"
	exit 0
}


Recover() {
	PrintBoth "**Recovery Mode**\n\n"
	CheckBrick
	if [ -e ./bakp4 ]; then
		Flash112
		FlashBakP4
	else
		PrintBoth "FATAL:  Backup P4 file not found.\n"
		exit 1
	fi	
	exit 0
}


Unbrick() {
	PrintBoth "**Unbrick Mode**\n\n"
	CheckBrick
	if [ -e ./bakp4 ]; then
		FlashBakP4
	else
		PrintBoth "FATAL:  Backup P4 file not found.\n"
		exit 1
	fi	

	exit 0
}


Brick() {
        PrintBoth "**Brick Mode**\n\n"
        PrintScreen "This will force QDL mode.  You need a backup P4 file!!  Are you SURE?\n"
	GetYN
	if [ ! -e ./bakp4 ]; then	
		PrintBoth "*** WARNING: NO backup p4 file \($PWD/bakp4\) found! ***\n"
		PrintScreen "Creating backup now..."
		BackupP4
	fi
	KillP4
	exit 0
}


SuperCID() {
	PrintBoth "**SuperCID Only Mode**\n\n"

	PrintBoth  "\nPreparing...\n"

	sleep 2
	./adb kill-server > /dev/null
	./adb start-server > /dev/null

	superCID=1
	
	if [ -e ./bakp4 ]; then
		mv ./bakp4 ./bakbakp4
	fi

	BackupP4
	mv ./bakp4 ./cidp4

	if [ -e ./bakbakp4 ]; then
		mv ./bakbakp4 ./bakp4
	fi
	
	./adb push ./cidp4 /sdcard > /dev/null
	./adb shell "dd if=/sdcard/cidp4 of=/dev/block/mmcblk0p4" > /dev/null
	./adb shell "rm /sdcard/cidp4" > /dev/null
	
	./adb reboot
	PrintBoth "Done\n"
	exit 0
}

##################
#  ===  UI  ===  #
##################

Interactive() {
	PrintScreen  "This script will put backup critical partition data and then put your phone\n"
	PrintScreen  "into Qualcomm download mode (AKA Brick).\n\n"
	PrintScreen  "Before running this script, you should have TWRP loaded onto your phone.\n"
	PrintScreen  "Plug your phone in via USB and ensure both USB debugging is enabled.\n\n"
	read -p "Press Enter to continue..." p

	PrintBoth  "\nPreparing...\n"


        sleep 2
	./adb kill-server > /dev/null
	./adb start-server > /dev/null


	PrintScreen  "This phase backs up /dev/block/mmcblk0p4 from your phone to this machine.  In\n" 
	PrintScreen  "addition, we will fetch your IMEI from the phone and use it to create an\n"
	PrintScreen  "additional partition 4 replacement to use as a failsafe.  In the \n"
	PrintScreen  "event something goes wrong, you'll have a way to unbrick manually.\n" 
	PrintScreen  "Please stand by...\n\n"

	BackupP4

	PrintScreen  "Phase 2\n\n"
	PrintScreen  "Now that we have backups, we're going to intentionally corrupt the\n" 
	PrintScreen  "data on /dev/block/mmcblk0p4.  This will cause the phone to enter\n"
	PrintScreen  "Qualcomm download mode (or brick if you prefer).\n\n"
	PrintScreen  "The process can't be stopped after this.  Continue?\n"
	GetYN

	PrintScreen  "\n\nDo NOT interrupt this process or reboot your computer.\n\n"
	PrintBoth  "Corrupting /dev/block/mmcblk0p4...\n\n"

	KillP4

	PrintBoth  "Success.\n\n\n"
	PrintScreen  "Your phone should now appear to be off, with no charging light on.\n\n"
	read -p "Press Enter to continue..." p

	CheckBrick

	Flash112

	PrintBoth  "\nSuccessfully loaded HBOOT 1.12.0000!\n\n\n"
	PrintScreen  "The final step is restoring your backup /dev/block/mmcblk0p4./n/n"
	PrintScreen  "Once again, if this process hangs at \"Waiting for /dev/sd"$brickdrive"4...\"\n"
	PrintScreen  "Press and hold the power button on your phone for no less than 30 seconds and\n"
	PrintScreen  "then release it.  The process should wake back up a few seconds afterwards.\n\n"
	PrintScreen  "If this process fails to complete you will need to complete the manual steps\n"
	PrintScreen  "using the post on XDA.  In that case, your bricked phone should be\n"
	PrintScreen  "accessible at /dev/sd$brickdrive\n\n"

	FlashBakP4

	PrintScreen  "HBOOT 1.12 downgrade complete.\n\n"
	PrintBoth  "Rebooting to live mode...\n\n"

	sleep 10
	WakeQDL

	PrintBoth  "Done.\n"
	exit 0

}


DisplayHelp() {
	PrintScreen "Invalid command line argument specified.\n\n"
	PrintScreen "Usage:  dg112.sh [options]\n\n"
	PrintScreen "   -b, --backup          Backup P4 and generate failsafe P4 only.  (No QDL force)\n"
	PrintScreen "   -c, --cidpreserve     Do not apply SuperCID mod to backup P4 file\n"
	PrintScreen "   -h, --help            Print this help and exit\n"
	PrintScreen "   -k, --kill            Kill P4 to force QDL mode (Be careful with this.)\n"
	PrintScreen "   -q, --quiet           Suppress all display output\n"
	PrintScreen "   -r, --recover         Load HBOOT 1.12 and load existing backup P4\n"
	PrintScreen "   -s, --supercid        Apply SuperCID mod to UNBRICKED phone\n"
	PrintScreen "   -u, --unbrick         Reload backup P4 only (force exit QDL)\n"
	PrintScreen "   -v  --verbose         Display all output\n\n"
	exit 1
}

#############################
#  ===  End Functions  ===  #
#############################

####################
#  ===  Main  ===  #
####################

clear
PrintScreen "HTC EVO 4G LTE HBOOT Downgrade Tool v$version\n\n"

mode=Interactive
for opt ; do
        case $opt in
        -b | --backup) mode=BackupOnly;;
		-c | --cidpreserve) superCID=0;;
		-k | --kill) mode=Brick;;
		-q | --quiet) verbose=0;;
		-r | --recover) mode=Recover;;
		-s | --supercid) mode=SuperCID;;
		-u | --unbrick) mode=Unbrick;;
		-v | --verbose) verbose=1;;
		*) DisplayHelp;;                  # handles -h, --help and any undefined args
	esac
done 

InitDG112

$mode

