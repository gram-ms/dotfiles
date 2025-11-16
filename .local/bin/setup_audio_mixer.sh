#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

VIRTUAL_SINK_NAME="virtual_combined"
VIRTUAL_MIC_NAME="virtual_mic"
VIRTUAL_MIC_DESC="VirtualMic (Mic+App)"
COMBINED_SINK_NAME="App_Monitor_and_Virtual_Sink"


# Function to clear ond configs
cleanup_existing() {
    echo -e "${CYAN} Cleaning old configs...${NC}"
    pactl list short modules | grep "module-combine-sink.*sink_name=$COMBINED_SINK_NAME" | while read -r line; do
        MODULE_ID=$(echo $line | cut -f1)
        echo "    -> Unload sink module (ID: $MODULE_ID)"
        pactl unload-module "$MODULE_ID"
    done
    pactl list short modules | grep "module-remap-source.*source_name=$VIRTUAL_MIC_NAME" | while read -r line; do
        MODULE_ID=$(echo $line | cut -f1)
        echo "    -> Unload virtual mike module (ID: $MODULE_ID)"
        pactl unload-module "$MODULE_ID"
    done
    pactl list short modules | grep "module-loopback" | while read -r line; do
        MODULE_ID=$(echo $line | cut -f1)
        echo "    -> Unload old loopback module (ID: $MODULE_ID)"
        pactl unload-module "$MODULE_ID"
    done
    pactl list short modules | grep "module-null-sink.*sink_name=$VIRTUAL_SINK_NAME" | while read -r line; do
        MODULE_ID=$(echo $line | cut -f1)
        echo "    -> Unload virtual sink module (ID: $MODULE_ID)"
        pactl unload-module "$MODULE_ID"
    done
    echo -e "${CYAN} Cleaning completed. ${NC}\n"
}

# Generic function to select a device
select_device() {
    local device_type=$1 # "sources" ou "sinks"
    local prompt_message=$2
    
    echo -e "${YELLOW}${prompt_message}${NC}"
    
    mapfile -t devices < <(pactl list short "$device_type" | grep -v ".monitor")

    if [ ${#devices[@]} -eq 0 ]; then
        echo "Error: Device: '$device_type' not found."
        exit 1
    fi

    for i in "${!devices[@]}"; do
        device_name=$(echo "${devices[$i]}" | cut -f2)
        echo "  [$((i+1))] - $device_name"
    done

    local choice
    while true; do
        read -p "Select the device number" choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#devices[@]}" ]; then
            DEVICE_ID=$(echo "${devices[$((choice-1))]}" | cut -f2)
            echo -e "${GREEN}✔ Device selected: ${DEVICE_ID}${NC}\n"
            eval "$3='$DEVICE_ID'"
            break
        else
            echo "Invalid option. Try again."
        fi
    done
}


main() {
    set -e
    clear
    echo -e "${GREEN}======================================================${NC}"
    echo -e "${GREEN}  Audio mixing configurator (v2 - Combine Sink)${NC}"
    echo -e "${GREEN}======================================================${NC}\n"

    cleanup_existing

    select_device "sources" " Select your MICROPHONE :" SELECTED_MIC

    select_device "sinks" " Select your audio OUTPUT :" SELECTED_SINK

    echo -e "${CYAN} Creating virtual sink :'${VIRTUAL_SINK_NAME}'...${NC}"
    pactl load-module module-null-sink sink_name="$VIRTUAL_SINK_NAME" sink_properties=device.description="VirtualCombined"
    echo -e "${GREEN} Virtual sink created.${NC}\n"

    echo -e "${CYAN} Creating a combined sink for monitoring...${NC}"
    pactl load-module module-combine-sink sink_name="$COMBINED_SINK_NAME" slaves="$SELECTED_SINK,$VIRTUAL_SINK_NAME" sink_properties=device.description="App_Monitor_and_Virtual_Sink"
    echo -e "${GREEN}✔ The sink '$COMBINED_SINK_NAME' was combined.${NC}\n"

    echo -e "${CYAN} Send MICROPHONE to virtual sink...${NC}"
    pactl load-module module-loopback source="$SELECTED_MIC" sink="$VIRTUAL_SINK_NAME" latency_msec=10
    echo -e "${GREEN}✔ MICROPHONE routed successfully.${NC}\n"

    echo -e "${CYAN} Creating virtual MICROPHONE '${VIRTUAL_MIC_NAME}' for better compatibility...${NC}"
    pactl load-module module-remap-source master="$VIRTUAL_SINK_NAME.monitor" source_name="$VIRTUAL_MIC_NAME" source_properties=device.description="$VIRTUAL_MIC_DESC"
    echo -e "${GREEN}✔ Virtual MICROPHONE created.${NC}\n"
    
    echo -e "${CYAN} Defining '${VIRTUAL_MIC_DESC}' as the  defaut MICROPHONE...${NC}"
    pactl set-default-source "$VIRTUAL_MIC_NAME"
    echo -e "${GREEN}✔ Default MICROPHONE defined.${NC}\n"

    echo -e "${YELLOW}=======================================================================================${NC}"
    echo -e "${YELLOW}                          >>> ACTION NEEDED <<< 
${NC}"
echo -e "   Open your audio app (Amplitude, Spotify, etc...) and, in configs selected the audio OUTPUT to:
"
    echo -e "   ${CYAN}▶ '$COMBINED_SINK_NAME' ◀${NC}
"
    echo -e "=======================================================================================${NC}"

    echo -e "\n${GREEN} EVERYTHING IS READY!${NC}"
    echo -e "----------------------------------------------------------------"
    echo -e "  - Microphone for use in Discord/OBS: '${CYAN}${VIRTUAL_MIC_DESC}${NC}'. (This is already)."
    echo -e "  - Output for use in your sound app: '${CYAN}${COMBINED_SINK_NAME}${NC}'."
    echo -e "----------------------------------------------------------------"
}

main
