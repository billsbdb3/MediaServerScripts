log () {
  m_time=`date "+%F %T"`
  echo $m_time" :: $scriptName :: $scriptVersion :: "$1 2>&1 | tee -a "/config/logs/$logFileName"
}

logfileSetup () {
  logFileName="$scriptName-$(date +"%Y_%m_%d_%I_%M_%p").txt"

  # delete log files older than 5 days
  find "/config/logs" -type f -iname "$scriptName-*.txt" -mtime +5 -delete
  
  if [ ! -f "/config/logs/$logFileName" ]; then
    echo "" > "/config/logs/$logFileName"
    chmod 666 "/config/logs/$logFileName"
  fi
}

getArrAppInfo () {
  # Get Arr App information
  if [ -z "$arrUrl" ] || [ -z "$arrApiKey" ]; then
    arrUrlBase="$(cat /config/config.xml | xq | jq -r .Config.UrlBase)"
    if [ "$arrUrlBase" == "null" ]; then
      arrUrlBase=""
    else
      arrUrlBase="/$(echo "$arrUrlBase" | sed "s/\///")"
    fi
    arrName="$(cat /config/config.xml | xq | jq -r .Config.InstanceName)"
    arrApiKey="$(cat /config/config.xml | xq | jq -r .Config.ApiKey)"
    arrPort="$(cat /config/config.xml | xq | jq -r .Config.Port)"
    arrUrl="http://127.0.0.1:${arrPort}${arrUrlBase}"
  fi
}

verifyApiAccess () {
  until false
  do
    arrApiTest=""
    arrApiVersion=""
    if [ -z "$arrApiTest" ]; then
      arrApiVersion="v3"
      arrApiTest="$(curl -s "$arrUrl/api/$arrApiVersion/system/status?apikey=$arrApiKey" | jq -r .instanceName)"
    fi
    if [ -z "$arrApiTest" ]; then
      arrApiVersion="v1"
      arrApiTest="$(curl -s "$arrUrl/api/$arrApiVersion/system/status?apikey=$arrApiKey" | jq -r .instanceName)"
    fi
    if [ ! -z "$arrApiTest" ]; then
      break
    else
      log "$arrName is not ready, sleeping until valid response..."
      sleep 1
    fi
  done
}

ConfValidationCheck () {
  if [ ! -f "/config/extended.conf" ]; then
    log "ERROR :: \"extended.conf\" file is missing..."
    log "ERROR :: Download the extended.conf config file and place it into \"/config\" folder..."
    log "ERROR :: Exiting..."
    exit
  fi
  if [ -z "$enableAutoConfig" ]; then
    log "ERROR :: \"extended.conf\" file is unreadable..."
    log "ERROR :: Likely caused by editing with a non unix/linux compatible editor, to fix, replace the file with a valid one or correct the line endings..."
    log "ERROR :: Exiting..."
    exit
  fi
}

updateProfilarrConfig() {
  local radarrApiVersion="v3"
  local configFilePath="/profilarr/config.yml"
  
  # Ensure Radarr is ready before fetching data
  verifyApiAccess

  # Fetch Radarr details (replace placeholders with actual API endpoints if needed)
  local radarrBaseUrl=$(cat /config/config.xml | xq | jq -r .Config.UrlBase)
  local radarrApiKey=$(cat /config/config.xml | xq | jq -r .Config.ApiKey)
  local radarrPort=$(cat /config/config.xml | xq | jq -r .Config.Port)
  
  if [ "$radarrBaseUrl" == "null" ]; then
    radarrBaseUrl=""
  else
    radarrBaseUrl="/$(echo "$radarrBaseUrl" | sed "s/\///")"
  fi
  
  local radarrUrl="http://127.0.0.1:${radarrPort}${radarrBaseUrl}"

  # Verify the API connection
  if [ -z "$(curl -s "$radarrUrl/api/$radarrApiVersion/system/status?apikey=$radarrApiKey" | jq -r .instanceName)" ]; then
    log "Failed to connect to Radarr API. Exiting Profilarr configuration update."
    exit 1
  fi

  # Update Profilarr `config.yml`
  log "Updating Profilarr configuration file: $configFilePath"
  
  cat <<EOF > "$configFilePath"
instances:
  radarr:
    - name: "RadarrInstance"
      base_url: "$radarrUrl"
      api_key: "$radarrApiKey"
  sonarr:
    - name: "DefaultSonarr"
      base_url: "http://localhost:8989"
      api_key: "SONARR_API_KEY"  # Replace with the real Sonarr API key if needed
settings:
  export_path: "./exports"
  import_path: "./imports"
  ansi_colors: true
EOF

  log "Profilarr configuration file updated successfully."
}
logfileSetup
ConfValidationCheck
