#!/bin/bash

RET=1

while [[ RET -ne 0 ]]; do
    sleep 1;
    mysql -e 'exit' > /dev/null 2>&1; RET=$?
done

mysql -u root -e "GRANT ALL PRIVILEGES ON *.* to 'root'@'%' WITH GRANT OPTION;"

if [ -f /srv/init.sh ]; then
    chmod +x /srv/init.sh
    /srv/init.sh
fi
