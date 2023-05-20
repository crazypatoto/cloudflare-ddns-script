#!/bin/bash

# ---------------------- Change the configurations accroding to your needs! ----------------------
api_key="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"      # Your Cloudflare API Key (Need Zone Read and DNS Edit permissions) 
zone_name="yourdomain.com"                           # Your domain name
record_name="ddns.yourdomain.com"                   # Your full domain name inculding subdomain
record_type="AAAA"                                  # 'A' for ipv4, 'AAAA' for ipv6

ip_index="local"                                    # use "internet" or "local" is accquire IP address
eth_interface="eth0"                                # the interface used to get IP address

ip_file="ip.txt"                                    # the file used to save IP address
# ----------------------------------- End of the configurations -----------------------------------

echo "Script Started..."

if [ $record_type = "AAAA" ];then
    if [ $ip_index = "internet" ];then
        ip=$(curl -6 ip.sb)
    elif [ $ip_index = "local" ];then
        if [ "$user" = "root" ];then
            ip=$(ifconfig $eth_interface | grep 'inet6'| grep -v '::1'| grep -v 'fe80' | cut -f2 | awk '{ print $2}' | head -1)
        else
            ip=$(/sbin/ifconfig $eth_interface | grep 'inet6'| grep -v '::1'| grep -v 'fe80' | cut -f2 | awk '{ print $2}' | head -1)
            #ip=$(/sbin/ifconfig $eth_interface | grep 'inet6'| grep -v '::1' | cut -f2 | awk '{ print $2}' | head -1)
        fi
    else 
        echo "Error IP index, please input the right type"
        exit 0
    fi
elif [ $record_type = "A" ];then
    if [ $ip_index = "internet" ];then
        ip=$(curl -4 ip.sb)
    elif [ $ip_index = "local" ];then
        if [ "$user" = "root" ];then
            ip=$(ifconfig $eth_interface | grep 'inet'| grep -v '127.0.0.1' | grep -v 'inet6'|cut -f2 | awk '{ print $2}')
        else
            ip=$(/sbin/ifconfig $eth_interface | grep 'inet'| grep -v '127.0.0.1' | grep -v 'inet6'|cut -f2 | awk '{ print $2}')
        fi
    else 
        echo "Error IP index, please input the right type"
        exit 0
    fi
else
    echo "Error DNS type"
    exit 0
fi

# Print current IP
echo "Current IP = " "$ip"


# Check if IP has changed?
if [ -f $ip_file ]; then
    old_ip=$(cat $ip_file)
    if [ $ip == $old_ip ]; then
        echo "IP has not changed."
        exit 0
    fi
fi

# Get Zone ID and record ID
zone_identifier=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone_name" \
    -H "Authorization: Bearer $api_key" \
    -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
record_identifier=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?type=${record_type}&name=$record_name" \
    -H "Authorization: Bearer $api_key" \
    -H "Content-Type: application/json"  | grep -Po '(?<="id":")[^"]*')

# Print Zone ID & Record ID
echo "Zone ID = " "$zone_identifier"
echo "Record ID = " "$record_identifier"

# Update DNS record
update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" \
    -H "Authorization: Bearer $api_key" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"$record_type\",\"name\":\"$record_name\",\"content\":\"$ip\",\"ttl\":1,\"proxied\":false}")


# Show Result
if [[ $update == *"\"success\":true"* ]]; then
    message="IP changed to: $ip"
    echo "$ip" > $ip_file
    echo "$message"
else
    message="API UPDATE FAILED. DUMPING RESULTS:\n$update"
    echo -e "$message"
    exit 1
fi
