echo " list symbols and sections "
objdump -tT esp_tcp |  grep " .text"
size -A esp_tcp | grep text

