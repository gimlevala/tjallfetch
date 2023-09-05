#!/bin/sh

## OS/ENVIRONMENT INFO DETECTION

ostype="$(uname)"

linuxtype=none
if command -v getprop > /dev/null; then
	linuxtype=android	
fi
kernel="$(echo $(uname -r) | cut -d'-'  -f1-1)"
case $ostype in
	"Linux"*)
		if [ $linuxtype = android ]; then
			host="$(hostname)"
			USER=${USER:-$(id -un || printf %s "${HOME/*\/}")}
			os="Android $(getprop ro.build.version.release)"
		else
			host="$(cat /proc/sys/kernel/hostname)"
			. /etc/os-release
			if [ -f /bedrock/etc/bedrock-release ]; then
				os="$(brl version)"
			else
				os="${PRETTY_NAME}"
			fi
		fi
		shell=${SHELL##*/};;
	"Darwin"*)
		host="$(hostname -f | sed -e 's/^[^.]*\.//')"
		while IFS='<>' read -r _ _ line _; do
			case $line in
				ProductVersion)
					IFS='<>' read -r _ _ mac_version _
					break;;
			esac
		done < /System/Library/CoreServices/SystemVersion.plist
		os="macOS ${mac_version}";;
	*)
		os="Idk"
		host="host"
esac

## PACKAGE MANAGER AND PACKAGES DETECTION

manager=$(which nix-env pkg yum zypper dnf rpm apt brew port pacman xbps-query emerge cave apk kiss pmm /usr/sbin/slackpkg bulge yay paru pacstall nala cpm pmm eopkg 2>/dev/null)
manager=${manager##*/}
case $manager in
	cpm) packages="$(cpm C)";;
	brew) packages="$(printf '%s\n' "$(brew --cellar)/"* | wc -l | tr -d '[:space:]')";;
	port) packages="$(port installed | wc -l)";;
	apt) packages="$(dpkg-query -f '${binary:Package}\n' -W | wc -l)";;
	nala) packages="$(dpkg-query -f '${binary:Package}\n' -W | wc -l)";;
	rpm) packages="$(rpm -qa --last| wc -l)";;
	yum) packages="$(yum list installed | wc -l)";;
	dnf) packages="$(dnf list installed | wc -l)";;
	zypper) packages="$(zypper se | wc -l)";;
	pacman) packages="$(pacman -Q | wc -l)";;
	yay) packages="$(yay -Q | wc -l)";;
	paru) packages="$(paru -Q | wc -l)";;
	pacstall) packages="$(pacstall -L | wc -l)";;
	kiss) packages="$(kiss list | wc -l)";;
	emerge) packages="$(qlist -I | wc -l)";;
	pkg) packages="$(pkg info | wc -l | tr -d ' ')";;
	cave) packages="$(cave show installed-slots | wc -l)";;
	xbps-query) packages="$(xbps-query -l | wc -l)";;
	nix-env) packages="$(nix-store -q --requisites /run/current-system/sw | wc -l)";;
	apk) packages="$(apk list --installed | wc -l)";;
	pmm) packages="$(/bedrock/libexec/pmm pacman pmm -Q 2>/dev/null | wc -l )";;
	eopkg) packages="$(eopkg li | wc -l)";;
	/usr/sbin/slackpkg) packages="$(ls /var/log/packages | wc -l)";;
	bulge) packages="$(bulge list | wc -l)";;
	*)
		packages="$(ls /usr/bin | wc -l)"
		manager="bin";;
esac

## UPTIME DETECTION

if [ $linuxtype = android ]; then
    uptime="$(echo $(uptime -p) | cut -c 4-)"
else
    case $ostype in
        "Linux")
            IFS=. read -r s _ < /proc/uptime;;
        *) 
            s=$(sysctl -n kern.boottime)
            s=${s#*=}
            s=${s%,*}
            s=$(($(date +%s) - s));;
    esac
    d="$((s / 60 / 60 / 24))"
    h="$((s / 60 / 60 % 24))"
    m="$((s / 60 % 60))"
    # Plurals
    [ "$d" -gt 1 ] && dp=s
    [ "$h" -gt 1 ] && hp=s
    [ "$m" -gt 1 ] && mp=s
    [ "$s" -gt 1 ] && sp=s
    # Hide empty fields.
    [ "$d" = 0 ] && d=
    [ "$h" = 0 ] && h=
    [ "$m" = 0 ] && m=
    [ "$m" != "" ] && s=
    # Make the output of uptime smaller.
    [ "$d" ] && uptime="$d day$dp, "
    [ "$h" ] && uptime="$uptime$h hour$hp, "
    [ "$m" ] && uptime="$uptime$m min$mp"
    [ "$s" ] && uptime="$uptime$s sec$sp"
    uptime=${uptime%, }
fi

## RAM DETECTION

case $ostype in
	"Linux")
		while IFS=':k '  read -r key val _; do
			case $key in
				MemTotal)
					mem_used=$((mem_used + val))
					mem_full=$val;;
				Shmem) mem_used=$((mem_used + val));;
				MemFree|Buffers|Cached|SReclaimable) mem_used=$((mem_used - val));;
			esac
		done < /proc/meminfo
		mem_used=$((mem_used / 1024)) 
		mem_full=$((mem_full / 1024));;
	"Darwin"*)
		mem_full=$(($(sysctl -n hw.memsize) / 1024 / 1024))
		while IFS=:. read -r key val; do
			case $key in
				*' wired'*|*' active'*|*' occupied'*)
					mem_used=$((mem_used + ${val:-0}));;
			esac
			done <<-EOF
				$(vm_stat)
						EOF

			mem_used=$((mem_used * 4 / 1024));;
	*)
		mem_full="idk"
		mem_used="idk"
esac
memstat="${mem_used}/${mem_full} MB"
if which expr > /dev/null 2>&1; then
	mempercent="($(expr $(expr ${mem_used} \* 100 / ${mem_full} ))%)"
fi

## DEFINE COLORS

bold='[1m'
black='[30m'
cbg='\033[46m'
red='[31m'
green='[32m'
yellow='[33m'
blue='[34m'
magenta='[35m'
cyan='[36m'
white='[37m'
grey='[90m'
reset='[0m'

## USER VARIABLES -- YOU CAN CHANGE THESE
fo="$(fortune -s)"

lc="${reset}${bold}${magenta}"  # labels
nc="${reset}${bold}${yellow}"   # user
hn="${reset}${bold}${blue}"     # hostname
ic="${reset}${green}"           # info
c0="${reset}${grey}"            # first color
c1="${reset}${white}"           # second color
c2="${reset}${yellow}"          # third color
c3="${reset}${bold}${grey}"
c4="${reset}${red}"
rb="${reset}${black}"
c5="${reset}${bold}${cyan}"
fb="${reset}${cbg}${black}"
## OUTPUT
echo -e ${rb} ${fb}${fo}${reset}
cat <<EOF
${c5} \      
${c5}  \  ${c3}_███_     ${nc}${USER}${red}@${reset}${hn}${host}${reset} 
${c5}   \ ${c0}(${c4}O o${c0}\    ${lc}  ${ic}${os}${reset}
${c0}     (${c2}<> ${c0}|    ${lc}  ${ic}${kernel}${reset}
${c0}    /${c1}/  \\ ${c0}\\   ${lc}󰍛  ${ic}${RAM}${memstat} ${mempercent}
${c0}   ( ${c1}|  | ${c0}/|  ${lc}󰏔  ${ic}${packages} (${manager})${reset}
${c2}  _${c0}/\\ ${c1}__)${c0}/${c2}_${c0})  ${lc}󰅶  ${ic}${uptime}${reset}
${c2}  \/${c0}-____${c2}\/${reset}   ${lc}  ${red}███${green}███${yellow}███${blue}███${magenta}███${cyan}███${reset}

EOF
