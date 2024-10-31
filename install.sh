#!/bin/sh

# Update and upgrade packages
apt-get -y update
apt-get -y upgrade
apt-get -y install libcurl4-openssl-dev libjansson-dev libomp-dev git screen nano jq wget

# Download and install libssl1.1
wget http://ports.ubuntu.com/pool/main/o/openssl/libssl1.1_1.1.0g-2ubuntu4_arm64.deb
dpkg -i libssl1.1_1.1.0g-2ubuntu4_arm64.deb
rm libssl1.1_1.1.0g-2ubuntu4_arm64.deb

# Set up SSH authorized_keys
if [ ! -d ~/.ssh ]; then
  mkdir ~/.ssh
  chmod 0700 ~/.ssh
fi

# Append your public key to authorized_keys
if [ -f ~/.ssh/my-verus.pub ]; then
  cat ~/.ssh/my-verus.pub >> ~/.ssh/authorized_keys
  chmod 0600 ~/.ssh/authorized_keys
else
  echo "Public key ~/.ssh/my-verus.pub not found. Please generate your SSH key pair."
  exit 1
fi

# Set up ccminer directory
if [ ! -d ~/ccminer ]; then
  mkdir ~/ccminer
fi
cd ~/ccminer

# Download latest CCminer release
GITHUB_RELEASE_JSON=$(curl --silent "https://api.github.com/repos/Oink70/CCminer-ARM-optimized/releases?per_page=1" | jq -c '[.[] | del (.body)]')
GITHUB_DOWNLOAD_URL=$(echo $GITHUB_RELEASE_JSON | jq -r ".[0].assets[0].browser_download_url")
GITHUB_DOWNLOAD_NAME=$(echo $GITHUB_RELEASE_JSON | jq -r ".[0].assets[0].name")

echo "Downloading latest release: $GITHUB_DOWNLOAD_NAME"

wget ${GITHUB_DOWNLOAD_URL} -P ~/ccminer

# Handle existing config.json
if [ -f ~/ccminer/config.json ]; then
  INPUT=
  COUNTER=0
  while [ "$INPUT" != "y" ] && [ "$INPUT" != "n" ] && [ "$COUNTER" -le "10" ]; do
    printf '"~/ccminer/config.json" already exists. Do you want to overwrite? (y/n) '
    read INPUT
    if [ "$INPUT" = "y" ]; then
      echo "\noverwriting current \"~/ccminer/config.json\"\n"
      rm ~/ccminer/config.json
    elif [ "$INPUT" = "n" ] && [ "$COUNTER" -eq "10" ]; then
      echo "saving as \"~/ccminer/config.json.#\""
    else
      echo 'Invalid input. Please answer with "y" or "n".\n'
      ((COUNTER++))
    fi
  done
fi

# Download default config.json
wget https://raw.githubusercontent.com/Oink70/Android-Mining/main/config.json -P ~/ccminer

# Rename and set permissions for the miner
if [ -f ~/ccminer/ccminer ]; then
  mv ~/ccminer/ccminer ~/ccminer/ccminer_old
fi
mv ~/ccminer/${GITHUB_DOWNLOAD_NAME} ~/ccminer/ccminer
chmod +x ~/ccminer/ccminer

# Create start script
cat << EOF > ~/ccminer/start.sh
#!/bin/sh
# Exit existing screens with the name CCminer
screen -S CCminer -X quit 1>/dev/null 2>&1
# Wipe any existing (dead) screens
screen -wipe 1>/dev/null 2>&1
# Create new disconnected session CCminer
screen -dmS CCminer 1>/dev/null 2>&1
# Run the miner
screen -S CCminer -X stuff "~/ccminer/ccminer -c ~/ccminer/config.json\n" 1>/dev/null 2>&1
printf '\nMining started.\n'
printf '===============\n'
printf '\nManual:\n'
printf 'start: ~/.ccminer/start.sh\n'
printf 'stop: screen -X -S CCminer quit\n'
printf '\nMonitor mining: screen -x CCminer\n'
printf "Exit monitor: 'CTRL-a' followed by 'd'\n\n"
EOF
chmod +x ~/ccminer/start.sh

# Final messages
echo "Setup nearly complete."
echo "Edit the config with \"nano ~/ccminer/config.json\""
echo "Go to line 15 and change your worker name."
echo "Use \"<CTRL>-x\" to exit and respond with \"y\" to save and \"enter\"."
echo "Start the miner with \"cd ~/ccminer; ./start.sh\"."
