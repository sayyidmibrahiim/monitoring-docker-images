# !bin/bash
path=/root/script/monitoring
DATE=$(date '+%Y-%m-%d  %H:%M:%S')
chat_id="{{YOUR CHAT_ID CHANNEL}}"
token="{{YOUR TOKEN BOT}}"
host=$(hostname)
ip=$(curl ifconfig.me)

#Save container images to container.properties file
if [ -z $(find "$path" -name "container.properties") ]; then
        docker ps -a | awk '{print$2}'| grep -v ID | cut -d ':' -f 1 >> $path/container.properties
else
#If container.properties file existed, then check if there any new images
        count_image=$(docker ps -a | awk '{print$2}'| grep -v ID | cut -d ':' -f 1 | wc -l)
        counter=1
        until [ "$counter" -gt "$count_image" ]; do
                images=$(docker ps -a | awk '{print$2}'| grep -v ID | cut -d ':' -f 1 | sort | awk 'NR=='"$counter"'{print$1}')
                if [[ $(grep "$images" $path/container.properties | wc -l) -eq 0 ]]; then
                        echo "$images" >> $path/container.properties
                fi
                ((counter++))
        done
fi


#Array for checking every images
declare -a arr=(
`awk '1' "$path/container.properties"`
)

#Looping for checking every images on container.properties file
for container in "${arr[@]}"
do
logs_state_name=$(grep "$container" "$path/container.properties" | tr / -)
if [[ $(docker ps -a | grep -i $container | wc -l) -eq 0 ]]; then
        echo "$DATE Image = $container is down" >> $path/logs/$logs_state_name.out
                if [ $(ls $path/state/ | grep $logs_state_name-down | wc -l) -le 0 ]; then
                        rm -f $path/state/$logs_state_name-*
                        curl -s -F chat_id="$chat_id" -F text="$host - $ip - Image = $container is down at $DATE" https://api.telegram.org/bot$token/sendMessage > /dev/null 2>&1
                        touch $path/state/$logs_state_name-down
                fi
fi
#Array for chechking every status#Array for chechking every status
status=(running restarting removing paused exited dead)
for status in "${status[@]}"
do
if [[ $(docker ps -a --filter status=$status | grep -i $container | wc -l) -eq 1 ]]; then
        echo "$DATE Image = $container is $status" >> $path/logs/$logs_state_name.out
                if [ $(ls $path/state/ | grep $logs_state_name-$status | wc -l) -le 0 ] ; then
                        rm -f $path/state/$logs_state_name-*
                        curl -s -F chat_id="$chat_id" -F text="$host - $ip - Image = $container is $status at $DATE" https://api.telegram.org/bot$token/sendMessage > /dev/null 2>&1
                        touch $path/state/$logs_state_name-$status
                fi
fi
done
done
