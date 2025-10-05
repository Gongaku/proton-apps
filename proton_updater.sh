#!/usr/bin/env bash

fedora_release="$(cut -d' ' -f 3 < /etc/fedora-release)"

declare -A apps=(
  ["protonmail"]="https://proton.me/download/mail/linux/version.json"
	["protonvpn"]="https://repo.protonvpn.com/fedora-$fedora_release-stable/protonvpn-stable-release/"
  ["protonpass"]="https://proton.me/download/PassDesktop/linux/x64/version.json"
)

declare -A rpm=(
	["protonmail"]="ProtonMail-desktop-beta.rpm"
	["protonpass"]="proton-pass-|-1.x86_64.rpm"
	["protonvpn"]="protonvpn-stable-release/protonvpn-stable-release-|-1.noarch.rpm"
)

#######################################
# Function to get the installed version of an RPM package
# Argument:
# 	RPM file to search for
# Output:
# 	Stirng containing rpm version
#######################################
get_installed_version() {
  rpm -qi "$1" | grep "Version" | awk '{print $3}'
}

#######################################
# Function to get the latest available version from the download page
# Argument:
# 	URI of download page
#######################################
get_latest_version() {
  local url="$1"

  curl -s "$url" \
		| grep -Eo '[0-9]+\.[0-9]+\.[0-9]+(-beta[0-9]+)?' \
		| sort -r \
		| head -n 1
}

#######################################
# Download specified version of rpm
# Argument:
# 	URI to download page
# 	RPM file name
# 	Version to download
#######################################
download_rpm() {
	local download_url="$1"
	local rpm_file="$2"
	local latest_version="$3"

	rpm_file="${rpm_file//|/$latest_version}"
	wget "$download_url/$rpm_file" -O "/tmp/$rpm_file"
	sudo dnf upgrade "/tmp/$rpm_file" -y
	rm "/tmp/$rpm_file"
}

#######################################
# Gets Proton application type/package
# Argument:
# 	Application name
#######################################
get_package() {
	local app_name="$1"
	case "$app_name" in
    "protonmail")
      package_name="proton-mail"
      ;;
    "protonvpn")
      package_name="protonvpn-stable-release"
      ;;
    "protonpass")
      package_name="proton-pass"
      ;;
    *)
      echo "Error: Unknown application: $app_name"
      return 1
      ;;
  esac

	printf "%s\n" "$package_name"
}

#######################################
# Application process steps
# Argument:
# 	Application name
#######################################
handle_app() {
  local app_name="$1"
  local download_url="${apps["$app_name"]}"
	local rpm_file="${rpm["$app_name"]}"
  local package_name=""
	package_name="$(get_package "$app_name")"

  echo "Processing $app_name..."

  if rpm -q "$package_name" &> /dev/null; then
    echo "$app_name is already installed."
  	installed_version=$(get_installed_version "$package_name")
  	echo "Installed version: $installed_version"

  	latest_version=$(get_latest_version "$download_url")

    if [[ -n "$latest_version" ]]; then
      echo "Latest available version: $latest_version"
      if [[ "$latest_version" != "$installed_version" ]]; then
        echo "A newer version is available. Downloading and updating..."
				download_url=$(dirname "$download_url")
				download_rpm "$download_url" "$rpm_file" "$latest_version"
        echo "$app_name updated to $latest_version."

      else
        echo "$app_name is already the latest version."
      fi
    else
      echo "Could not determine the latest available version for $app_name."
    fi
  else
    echo "$app_name is not installed. Downloading and installing..."
  	latest_version=$(get_latest_version "$download_url")
		download_rpm "$download_url" "$rpm_file" "$latest_version"
    echo "$app_name installed."
  fi
  echo ""
}

main() {
	program="$1"
	case "$program" in
		*mail|*pass|*vpn)
			handle_app "$program" >&2
			;;
		*)
			cat <<- EOF
			Usage: ${BASH_SOURCE[0]##*/} PROTON-APP

			This is a script meant to update the linux version of a given Proton Application

			 PROTON-APP   Name of the Proton application.
										Options: protonpass, protonmail, protonvpn
			EOF
			exit 0
			;;
	esac
}

main "$@"
