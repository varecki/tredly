#!/usr/bin/env bash

# prints out a nicely formatted menu for the user to configure their system
function tredlyHostMenuConfig() {
    
    local _userSelection _userChange
    
    # for our loop
    continue="true"
    
    local _i=0
    while [[ "${continue}" == "true" ]]; do
        clear
        echo -e "${_colourMagenta}"
        e_header "Tredly v1.0 Installer"
        
        echo -en "${_colourDefault}"
        
        {
            echo -e "1.^External Interface^${_configOptions[1]}"
            echo -e "2.^External IP Address (including CIDR)^${_configOptions[2]}"
            echo -e "3.^External Gateway^${_configOptions[3]}"
            echo -e "4.^Hostname^${_configOptions[4]}"
            echo -e "5.^Container Subnet^${_configOptions[5]}"
            echo -e "6.^API IPv4 Whitelist^${_configOptions[6]}"
            echo -e "7.^Tredly Command Center URL^${_configOptions[7]}"
            
            echo -en "8.^Root User Password^"
            # dont display passwords if they arent == tredly
            if [[ "${_configOptions[8]}" != "tredly" ]]; then
                echo -e "********"
            else
                echo -e "${_configOptions[8]}"
            fi
            
            echo -en "9.^Tredly User Password^"
            # dont display passwords if they arent == tredly
            if [[ "${_configOptions[9]}" != "tredly" ]]; then
                echo -e "********"
            else
                echo -e "${_configOptions[9]}"
            fi
            
            echo -en "10.^Tredly API Password^"
            # dont display passwords if they arent == tredly
            if [[ "${_configOptions[10]}" != "tredly" ]]; then
                echo -e "********"
            else
                echo -e "${_configOptions[10]}"
            fi
            
            # if this isnt the first loop then give the option to continue installation
            if [[ ${_i} -ne 0 ]]; then
                echo -e " ^ ^ "
                echo -e "0.^Proceed With Installation^ "
            fi
            
        } | column -ts ^
        echo -e "${_colourDefault}"
        
        _userSelection=""
        
        # if this is the first loop then do auto install
        if [[ ${_i} -eq 0 ]];then
            echo "Press enter to configure Tredly."
            
            # number of seconds to wait for user intervention
            local _timeout="10"
            # fire off a warning to the user in the background
            seq ${_timeout} 1 | while read _n; do echo -en "\rInstallation will continue in ${_n} seconds "; sleep 1; done &
            
            # get the pid from the counter we just fired off
            _counterPid=$!
            
            read -t ${_timeout} -p "" _userSelection
            local _configureOptionExitCode=$?
            
            # kill off the countdown
            disown ${_counterPid}
            kill ${_counterPid} > /dev/null 2>&1
            
            # if read received no answer then proceed with installation
            if [[ ${_configureOptionExitCode} -eq 142 ]]; then
                continue="false"
                # echo a line to fix up echos after the countdown
                echo ""
            fi
            
        else
            # read users selection
            read -p "Enter option number to configure: " _userSelection
            
            # validate user input
            case ${_userSelection} in
                0)
                    # confirm
                    local _confirmProceed
                    read -p "Proceed with installation? (y/n): " _confirmProceed
                    if [[ ${_confirmProceed} == 'y' ]]; then
                        # proceed with installation
                        continue="false"
                    fi
                ;;
                1)
                    # external interface
                    tredlySelectExternalInterface
                ;;
                2)
                    # external ip address incl cidr
                    tredlySelectExternalIP
                ;;
                3)
                    # external gateway
                    tredlySelectExternalGateway
                ;;
                4)
                    # hostname
                    tredlySelectHostname
                ;;
                5)
                    # container subnet
                    tredlySelectContainerSubnet
                ;;
                6)
                    # api whitelist
                    tredlySelectApiWhitelist
                ;;
                7)
                    # tredly command center
                    tredlySelectCommandCenterURL
                ;;
                8)
                    # set root password
                    tredlySetPassword "root" 8
                ;;
                9)
                    # set tredly password
                    tredlySetPassword "tredly" 9
                ;;
                10)
                    # set tredly password
                    tredlySetPassword "tredly api" 10
                ;;
                *)
                    echo "Invalid input \"${_userSelection}\""
                ;;
            esac
       fi
       _i=$(( _i + 1 ))
    done
}

# allows user to select their external iface
function tredlySelectExternalInterface() {
    local _externalInterface=''
    local _userSelectInterface=''
    
    # get a list of interfaces
    IFS=$'\n' _interfaces=($( getExternalInterfaces ))
    
    while [[ -z "${_externalInterface}" ]]; do
        # have the user select the interface
        echo "More than one interface was found on this machine:"
        for _i in ${!_interfaces[@]}; do
            echo "$(( ${_i} + 1 )). ${_interfaces[${_i}]}"
        done

        read -p "Select your external interface: [${_configOptions[1]}] " _userSelectInterface

        # if the user hit enter then set the default
        if [[ -z "${_userSelectInterface}" ]]; then
            _externalInterface="${_configOptions[1]}"
        elif [[ ${_userSelectInterface} -lt 1 ]] || [[ ${_userSelectInterface} -gt ${#_interfaces[@]} ]] || ! is_int ${_userSelectInterface}; then # ensure that the value we received lies within the bounds of the array
            e_error "Invalid selection. Please try again."
            _userSelectInterface=''
        elif [[ -n "$( ifconfig | grep "^${_interfaces[$(( ${_userSelectInterface} - 1 ))]}:" )" ]]; then
            _externalInterface="${_interfaces[$(( ${_userSelectInterface} - 1 ))]}"
        fi
    done

    
    # return what was selected
    _configOptions[1]="${_externalInterface}"
}

# allows user to set their ip address and cidr
function tredlySelectExternalIP() {
    local _userInput
    
    # var for loop
    local _valid="false"
    
    while [[ "${_valid}" == "false" ]]; do
        read -p "External IP Address: [${_configOptions[2]}] " _userInput
    
        # if the user hit enter then use the default
        if [[ -z "${_userInput}" ]]; then
            _valid="true"
        elif [[ ${_userInput} =~ ^(.*)/([[:digit:]]+)$ ]]; then # now validate it
            local -a re
            re=("${BASH_REMATCH[@]}")
            
            # validate the values
            if is_valid_ip4 "${re[1]}" && is_valid_cidr "${re[2]}"; then
                _valid="true"
                # set it in the global
                _configOptions[2]="${_userInput}"
            else
                echo "Please enter in the format ip/cidr. Eg. 10.99.0.0/16"
            fi
        fi
    done
}

function tredlySelectExternalGateway() {
    local _userInput
    
    # var for loop
    local _valid="false"
    
    while [[ "${_valid}" == "false" ]]; do
        read -p "External Gateway IP: [${_configOptions[3]}] " _userInput

        # validate the value
        if [[ -z "${_userInput}" ]]; then
            # if the user hit enter then use the default
            _valid="true"
        elif is_valid_ip4 "${_userInput}"; then
            _valid="true"
            # set it in the global
            _configOptions[3]="${_userInput}"
        else
            echo "Invalid IP4"
        fi
    done
}

# select and validate hostname
function tredlySelectHostname() {
    local _userInput
    
    # var for loop
    local _valid="false"
    
    while [[ "${_valid}" == "false" ]]; do
        read -p "Hostname: [${_configOptions[4]}] " _userInput
    
        # if the user hit enter then go with the default
        if [[ -z "${_userInput}" ]]; then
            _valid="true"
        elif is_valid_hostname "${_userInput}"; then # validate the value
            _valid="true"
            # set it in the global
            _configOptions[4]="${_userInput}"
        else
            echo "Invalid Hostname. Please try again"
        fi
    done
}

# allows user to set their container (private) subnet
function tredlySelectContainerSubnet() {
    local _userInput
    
    # var for loop
    local _valid="false"
    
    while [[ "${_valid}" == "false" ]]; do
        read -p "Container Subnet: [${_configOptions[5]}] " _userInput
    
        # now validate it
        regex="^(.*)\/([[:digit:]]+)$"
        [[ ${_userInput} =~ ${regex} ]]
        local -a re
        re=("${BASH_REMATCH[@]}")
        
        # if the user hit enter then use the default
        if [[ -z "${_userInput}" ]]; then
            _valid="true"
        elif is_valid_ip4 "${re[1]}" && is_valid_cidr "${re[2]}"; then # validate the values
            _valid="true"
            # set it in the global
            _configOptions[5]="${_userInput}"
        else
            echo "Please enter in the format ip/cidr. Eg. 10.99.0.0/16"
        fi
    done
}

# allows user to set their tredly build repo
function tredlySelectBuildRepo() {
    local _userInput
    
    # var for loop
    local _valid="false"
    
    while [[ "${_valid}" == "false" ]]; do
        read -p "Tredly Build GIT URL: " _userInput
    
        # validate it
        if [[ -n "${_userInput}" ]]; then
            _valid="true"
            # set hte global
            _configOptions[6]="${_userInput}"
        fi
    done
}

# allows user to set their container (private) subnet
function tredlySelectBuildBranch() {
    local _userInput
    
    # var for loop
    local _valid="false"
    
    while [[ "${_valid}" == "false" ]]; do
        read -p "Tredly Build Branch Name: " _userInput
    
        # validate it
        if [[ -n "${_userInput}" ]]; then
            _valid="true"
            # set the global
            _configOptions[7]="${_userInput}"
        fi
    done
}

# allows user to set their tredly-api URL
function tredlySelectAPIURL() {
    local _userInput
    
    # var for loop
    local _valid="false"
    
    while [[ "${_valid}" == "false" ]]; do
        read -p "Tredly Build GIT URL (blank for do not install): " _userInput
    
        _valid="true"
        # set the global
        _configOptions[8]="${_userInput}"
    done
}

# allows user to set their container (private) subnet
function tredlySelectAPIBranch() {
    local _userInput
    
    # var for loop
    local _valid="false"
    
    while [[ "${_valid}" == "false" ]]; do
        read -p "Tredly API Branch Name: " _userInput
        
        # validate it
        if [[ -n "${_userInput}" ]]; then
            _valid="true"
            # set the global
            _configOptions[9]="${_userInput}"
        fi
    done
}

# allows user to set their container (private) subnet
function tredlyDownloadSource() {
    local _userInput
    
    # var for loop
    local _valid="false"
    
    while [[ "${_valid}" == "false" ]]; do
        read -p "Tredly API Branch Name: " _userInput
        
        # validate it
        if [[ -n "${_userInput}" ]]; then
            _valid="true"
            # set the global
            _configOptions[9]="${_userInput}"
        fi
    done
}

function tredlySelectDownloadKernel() {
    local _userInput
    
    # var for loop
    local _valid="false"
    
    while [[ "${_valid}" == "false" ]]; do
        read -p "Download Kernel Source (y/n): " _userInput
        
        # validate it
        if [[ "${_userInput}" == "y" || "${_userInput}" == "n" ]]; then
            _valid="true"
            # set the global
            _configOptions[10]="${_userInput}"
        fi
    done
}

function tredlySelectApiWhitelist() {
    local _userInput
    
    # var for loop
    local _valid="false"
    
    while [[ "${_valid}" == "false" ]]; do
        echo "Please enter a list of ip addresses or network ranges, separated by commas"
        read -p "Tredly API Whitelist: " _userInput
        
        # accept enter
        if [[ -z "${_userInput}" ]]; then
            _valid="true"
        else
            # validate it
            IFS=',' read -ra _whitelistArray <<< "${_userInput}"
        
            for ip in ${_whitelistArray[@]}; do
                if ! is_valid_ip_or_range "${ip}"; then
                    e_error "${ip} is an invalid ip address or range"
                    _valid="false"
                else
                    _valid="true"
                fi
            done
    fi

        if [[ "${_valid}" == "true" ]]; then
            # set the global
            _configOptions[6]="${_userInput}"
        fi
    done
}

function tredlySelectCommandCenterURL() {
    local _userInput
    
    # var for loop
    local _valid="false"
    
    while [[ "${_valid}" == "false" ]]; do
        echo "Please enter the URL on which Command Center will respond to:"
        read -p "Command Center URL: [${_configOptions[7]}] " _userInput

        if [[ -z "${_userInput}" ]]; then
            _valid="true"
        elif is_valid_hostname "${_userInput}"; then
            _valid="true"
            _configOptions[7]="${_userInput}"
        else
            e_error "${_userInput} is not a valid hostname"
            _valid="false"
        fi
    done
}

function tredlySetPassword() {
    local _username="${1}"
    local _configOptionsKey="${2}"
    
    # make sure we received some options
    if [[ -z "${_username}" ]] || [[ -z "${_configOptionsKey}" ]]; then
        return
    fi
    
    # var for loop
    local _valid="false"
    local _userInput1='a'
    local _userInput2='b'
    
    echo "" 
    
    # passwords must match
    while [[ "${_userInput1}" != "${_userInput2}" ]]; do

        read -sp "Password for ${_username}: " _userInput1
        echo ""
        read -sp "Confirm password: " _userInput2
        echo ""

        # make sure they match
        if [[ "${_userInput1}" != "${_userInput2}" ]]; then
            echo "Passwords do not match. Try again."
        fi
    done
    
    # set the password
    _configOptions[${_configOptionsKey}]="${_userInput1}"
}