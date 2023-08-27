#!/bin/bash

# Colors
BLUE=$(tput setaf 24)
GRAY=$(tput setaf 7)
PURPLE=$(tput setaf 93)
RESET=$(tput sgr0)
GREEN=$(tput setaf 82)
WHITE=$(tput setab 235)
SEPARATOR="${BLUE}${WHITE}------------------------------------------------------------------------------${RESET}"

# Detect OS name and version
if command -v lsb_release &>/dev/null; then
    os_name=$(lsb_release -is)
    os_version=$(lsb_release -rs)
else
    os_name="Unknown"
    os_version="Unknown"
fi

echo "${GREEN}Detected OS:${RESET} ${GREEN}$os_name $os_version${RESET}"
echo "$SEPARATOR"

# Check for nping installation (part of nmap package)
if ! which nping > /dev/null; then
    echo "The nping utility (part of the ${PURPLE}nmap${RESET} package) is not installed."
    read -p "Would you like to install ${PURPLE}nmap${RESET}? (Y/n) " response
    case $response in
        [yY][eE][sS]|[yY])
            # Install nmap
            install_nmap() {
                local package_managers=("apt" "yum" "dnf" "zypper")  # Add more package managers if needed

                for manager in "${package_managers[@]}"; do
                    if command -v "$manager" &>/dev/null; then
                        echo "Installing nmap using $manager..."
                        sudo "$manager" update
                        sudo "$manager" install -y nmap
                        return 0  # Successful installation
                    fi
                done

                echo "Unable to install nmap. Please install it manually and rerun the script."
                return 1  # Unsuccessful installation
            }

            install_nmap
            ;;
        *)
            echo "This script requires nping (part of ${PURPLE}nmap${RESET}) to function. Exiting..."
            exit 1
            ;;
    esac
fi

# Declare the available pools and their ports
declare -A pools=(
    ["pool.gntl.uk"]="10007"
    ["pool.gntl.cash"]="10007"
    ["gntl.digiminer.co.uk"]="10007"
    ["fastpool.xyz"]="10241"
    ["au.fastpool.xyz"]="10241"
    ["us.fastpool.xyz"]="10241"
    ["asia.fastpool.xyz"]="10241"
    ["gntl.ausminers.com"]="4444"
    ["gntl.supportcryptonight.com"]="6655"
    ["gntl-miner.azpool.win"]="5555"
    ["gntl.pool-pay.com"]="4734"
)

results=()

# Capture user input for which pools to test
get_user_choice() {
    local choice
    local valid
    local options=("${!pools[@]}" "All" "Exit")

    echo "Available pools:"
    for i in "${!options[@]}"; do
        echo "$((i+1)). ${options[$i]}"
    done

    while true; do
        read -p "Select pools to test (comma separated numbers, e.g., 1,2 or 'All' or 'Exit'): " choice
        IFS=',' read -ra chosen <<< "$choice"

        valid=true
        chosen_pools=()

        for item in "${chosen[@]}"; do
            # Check for valid input
            if [[ $item -lt 1 || $item -gt ${#options[@]} ]]; then
                valid=false
                break
            fi

            # Populate array with selected pools
            pool="${options[$((item-1))]}"
            if [[ $pool == "Exit" ]]; then
                exit 0
            elif [[ $pool == "All" ]]; then
                chosen_pools=("${!pools[@]}")
                break
            else
                chosen_pools+=("$pool")
            fi
        done

        if $valid; then
            break
        else
            echo "Invalid choice. Please choose from the listed options."
        fi
    done
}

# Display a progress bar during testing
print_progress() {
    current=$1
    total=$2
    percent=$((100*current/total))
    bar_length=$((100*current/total))

    printf "Progress: ["
    for ((i=0; i<bar_length; i++)); do
        printf "#"
    done
    for ((i=bar_length; i<100; i++)); do
        printf " "
    done
    printf "] %3d%%\r" "$percent"
}

# Capture user input on which pools to test
get_user_choice

# Initialize counter variables
total_pools=${#chosen_pools[@]}
current_pool=0

clear
sleep 1

# Loop through the selected pools to test RTT
for host in "${chosen_pools[@]}"; do
    current_pool=$((current_pool + 1))
    print_progress "$current_pool" "$total_pools"
    
    port="${pools[$host]}"
    avg_rtt=$(nping --tcp -p "$port" -c 1 "$host" | grep "Avg rtt" | awk -F ':' '{print $4}' | tr -d ' ms')
    results+=("Avg RTT: $avg_rtt ms - Pool: $host, Port: $port")
done

clear
sleep 1
echo

# Sort results by RTT
IFS=$'\n' sorted_results=($(sort -k 2 -n <<< "${results[*]}"))
unset IFS

echo "${GRAY}+----------------------------------------------+"
echo "|              Pools sorted by RTT             |"
echo "+----------------------------------------------+${RESET}"


for result in "${sorted_results[@]}"; do
    rtt_value=$(echo "$result" | grep -Eo 'Avg RTT: [0-9.]+ ms')
    pool_data=$(echo "$result" | grep -Eo 'Pool: .+')
    echo -e "${BLUE}$rtt_value${RESET} - ${GREEN}$pool_data${RESET}"
done

# Find the pool with the shortest RTT
shortest_rtt=$(printf "%s\n" "${sorted_results[@]}" | grep -Eo 'Avg RTT: [0-9.]+' | awk '{print $3}' | sort -n | head -n 1)
shortest_pool=$(printf "%s\n" "${sorted_results[@]}" | grep "Avg RTT: $shortest_rtt" | awk -F 'Pool: ' '{print $2}' | head -n 1)

echo "$SEPARATOR"
echo "${GRAY}Result:${RESET}"
echo -e "${BLUE}Shortest RTT${RESET}: $shortest_rtt ms"
echo -e "${GREEN}Pool${RESET}: $shortest_pool"
echo "$SEPARATOR"
echo
echo
