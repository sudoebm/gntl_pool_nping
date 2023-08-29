#!/bin/bash

# Debug mode
debug_mode="false"

# Colors
BLUE=$(tput setaf 24)
RED=$(tput setaf 196)
GRAY=$(tput setaf 7)
PURPLE=$(tput setaf 93)
RESET=$(tput sgr0)
GREEN=$(tput setaf 82)
WHITE=$(tput setab 235)
TERM_WIDTH=$(tput cols)
SEPARATORD="${RED}${WHITE}$(printf '%*s' "$TERM_WIDTH" '' | tr ' ' -)${RESET}"
SEPARATOR="${BLUE}${WHITE}$(printf '%*s' "$TERM_WIDTH" '' | tr ' ' -)${RESET}"

# Check if a command is available
check_command_installed() {
    if ! command -v "$1" &> /dev/null; then
        echo "${RED}Error:${RESET} $1 is not installed. Please install $1 to proceed."
        exit 1
    fi
}

# Install packages
install_packages() {
    local package_name="$1"
    local package_managers=("apt" "yum" "dnf" "zypper")  # Add more package managers in the future

    for manager in "${package_managers[@]}"; do
        if command -v "$manager" &>/dev/null; then
            echo "Installing $package_name using $manager..."
            sudo "$manager" update
            sudo "$manager" install -y "$package_name"
            if command -v "$package_name" > /dev/null; then
                echo "${GREEN}$package_name installation successful.${RESET}"
            else
                echo "${RED}Unable to verify $package_name installation. Please make sure $package_name is installed.${RESET}"
            fi
            return 0  # Successful installation
        fi
    done

    echo "${RED}Unable to install $package_name using any supported package manager.${RESET}"
    return 1  # Installation failed
}

# Ask for permission to install
ask_permission() {
    local package_name="$1"
    read -p "Would you like to install ${PURPLE}$package_name${RESET}? (Y/n) " response
    case $response in
        [yY][eE][sS]|[yY])
            install_packages "$package_name"
            ;;
        *)
            echo "This script requires $package_name to function. Exiting..."
            exit 1
            ;;
    esac
}

# Detect OS/name/version (for later)
detect_os() {
    if command -v lsb_release &>/dev/null; then
        os_name=$(lsb_release -is)
        os_version=$(lsb_release -rs)
    elif [ -f /etc/os-release ]; then
        # source the os-release file
        . /etc/os-release
        os_name=$NAME
        os_version=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        os_name=$(cat /etc/redhat-release | awk '{print $1}')
        os_version=$(cat /etc/redhat-release | awk '{print $3}')
    else
        os_name="Unknown"
        os_version="Unknown"
    fi
}

# Check if jq is installed
check_command_installed jq

# Check if nping is installed
check_command_installed nping

# GNTL miningpoolstats.stream webpage anchor for search function (Epoch time workaround)
webpage_url="https://miningpoolstats.stream/gntlcoin"
webpage_source=$(wget -qO- "$webpage_url")

# Extract timestamp from webpage source
timestamp=$(echo "$webpage_source" | grep -oE 'href="https://data.miningpoolstats.stream/data/gntlcoin.js\?t=[0-9]+"' | grep -oE '[0-9]+')

# Create API URL with extracted timestamp
api_url="https://data.miningpoolstats.stream/data/gntlcoin.js?t=$timestamp"
response=$(wget -qO- "$api_url")

# Array to store pool data
declare -A pools

# Extract information using jq and store in the array
pool_count=$(echo "$response" | jq '.data | length')

for ((i=0; i<$pool_count; i++)); do
    pool=$(echo "$response" | jq -r ".data[$i]")
    url=$(echo "$pool" | jq -r '.url | sub("https?://";"") | sub("/.*$";"")')
    port=$(echo "$pool" | jq -r '.port')
    pools["$url"]="$port"
done

# Declare the chosen_pools array
declare -A chosen_pools

# Capture user input on which pools to test
get_user_choice() {
    local choice
    local valid
    # Include an "All" and "Exit" option
    local options=("${!pools[@]}" "All" "Exit")

    clear
    sleep 1
    echo -e "${BLUE}Available pools:${RESET}"
    for i in "${!options[@]}"; do
        echo "$((i+1)). ${options[$i]}"
    done

    while true; do
        read -p "Select pools to test (comma separated numbers, e.g., 1,2 or 'All' or 'Exit'): " choice
        IFS=',' read -ra chosen <<< "$choice"

        valid=true

        for item in "${chosen[@]}"; do
            # Input Validation
            if [[ $item -lt 1 || $item -gt ${#options[@]} ]]; then
                valid=false
                break
            fi

            # Populate array with selected pools
            pool="${options[$((item-1))]}"
            if [[ $pool == "Exit" ]]; then
                exit 0
            elif [[ $pool == "All" ]]; then
                for p in "${!pools[@]}"; do
                    chosen_pools["$p"]=1
                done
                break
            else
                chosen_pools["$pool"]=1
            fi
        done

        if $valid; then
            break
        else
            echo "Invalid choice. Please choose from the listed options."
        fi
    done
}

# Function to print progress
print_progress() {
    current=$1
    total=$2
    percent=$((100*current/total))

    bar_max_length=$((TERM_WIDTH * 3 / 4 - 20))  # Progress: [", "]", and the percent of value
    bar_length=$((bar_max_length * current / total))

    printf "Progress: ["
    for ((i=0; i<bar_length; i++)); do
        printf "#"
    done
    for ((i=bar_length; i<bar_max_length; i++)); do
        printf " "
    done
    printf "] %3d%%\r" "$percent"
}

# Capture user input on which pools to test
get_user_choice

# Debug print to check the chosen pools
echo "Chosen Pools: ${!chosen_pools[@]}"

# Initialize counter variables
total_pools=${#chosen_pools[@]}
current_pool=0

# Declare the results array
declare -a results

sort_results() {
    IFS=$'\n' sorted_results=($(echo "${results[*]}" | sort -t':' -k2 -n))
    unset IFS
}

# Loop through the selected pools to test RTT
for host in "${!chosen_pools[@]}"; do
    current_pool=$((current_pool + 1))
    print_progress "$current_pool" "$total_pools"
    
    avg_rtt=$(nping -H "$host" --tcp -c 1 | grep "Avg rtt" | awk -F ':' '{print $4}' | tr -d ' ms')
    results+=("Avg RTT: $avg_rtt ms - Pool: $host")
done

# Sort results by RTT
sort_results

# Debug mode
# ==================================================================================================================================================================================
if [ "$debug_mode" = "true" ]; then
    echo 
    echo -e "$SEPARATORD"
    echo 
    detect_os #for later
    echo "Detected OS: $os_name $os_version" #for later
    echo "Total Pools: $total_pools"
    echo "Chosen Pools: ${!chosen_pools[@]}"
    echo "${RED}Debug Mode:${RESET} Height: $height"
    echo "${RED}Debug Mode:${RESET} Block Height OK: $block_height_ok"
    echo "${RED}Debug Mode:${RESET} Difficulty: $difficulty"
    echo "${RED}Debug Mode:${RESET} Hashrate from Difficulty: $hashrate_from_diff"
    echo "${RED}Debug Mode:${RESET} Extracted Timestamp: $timestamp"
    echo 
    echo -e "$SEPARATORD"
    echo 
    echo "${RED}Debug Mode:${RESET} API Response: $response"
    echo 
    echo -e "$SEPARATORD"
    echo 
fi
# ==================================================================================================================================================================================

# Display sorted results
echo "${GRAY}+----------------------------------------------+"
echo "|              Pools sorted by RTT             |"
echo "+----------------------------------------------+${RESET}"

for result in "${sorted_results[@]}"; do
    rtt_value=$(echo "$result" | grep -Eo 'Avg RTT: [0-9.]+ ms')
    pool_data=$(echo "$result" | grep -Eo 'Pool: .+')
    echo -e "${BLUE}$rtt_value${RESET} - ${GREEN}$pool_data${RESET}"
done

# Find the pool with the shortest RTT
shortest_rtt=$(echo "${sorted_results[0]}" | grep -Eo '[0-9.]+' | head -n 1)
shortest_pool=$(echo "${sorted_results[0]}" | grep -Eo 'Pool: .+' | awk -F 'Pool: ' '{print $2}')

echo "$SEPARATOR"
echo "${GRAY}Result:${RESET}"
echo -e "${BLUE}Shortest RTT${RESET}: $shortest_rtt ms"
echo -e "${GREEN}Pool${RESET}: $shortest_pool"
echo "$SEPARATOR"
echo
