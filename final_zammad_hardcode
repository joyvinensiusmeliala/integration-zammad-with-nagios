#!/bin/bash

ZAMMAD_TOKEN="oIe12Gjw_F0Xm5byX6qRRTLH_6glomQW9Zdn03e9xi0"
ZAMMAD_URL="http://192.168.30.187:81/api/v1"
LOG_FILE="/usr/local/nagios/libexec/log_test.txt"


# Mengambil tiket terbaru dengan judul "Termonitor host Bot Telegram - DOWN" dan menampilkan judul dan state_id
get_last_ticket_info() {
    curl_output=$(curl -s -X GET -H "Authorization: Bearer $ZAMMAD_TOKEN" "$ZAMMAD_URL/tickets?query=article.title:Termonitor%20host%20Bot%20Telegram%20-%20DOWN")
    state_id=$(echo "$curl_output" | jq -r '.[] | select(.title == "Termonitor host Bot Telegram - DOWN") | .state_id' | head -n 1)
    echo "$state_id"
}


state_id_open() {
    echo 2;
}

# Menyimpan informasi tiket ke dalam file log
echo "$(date '+%Y-%m-%d %H:%M:%S') - Informasi tiket terakhir: $ticket_info" >> "$LOG_FILE"

# Fungsi untuk membuat tiket baru
create_ticket() {
    # Memanggil fungsi untuk mendapatkan informasi terakhir dari tiket
    
    STATE_ID_OPEN=$(state_id_open)
    STATE_ID_OPEN_VALUE=$(echo "$STATE_ID_OPEN")

    # Jika tiket terakhir tidak ditemukan atau tidak dalam status "open" (state_id!=2)
    if [ "$(get_last_ticket_info)" != "$(state_id_open)" ]; then
        CUSTOMER_ID=$(curl -s -H "Authorization: Bearer $ZAMMAD_TOKEN" "$ZAMMAD_URL/users/search?query=soc.monitoring@privy.id" | jq -r '.[0].id')

        TICKET_RESPONSE=$(curl -s -X POST \
            -H "Authorization: Bearer $ZAMMAD_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"title\":\"Termonitor host Bot Telegram - DOWN\",\"group\":\"Users\",\"state_id\":2,\"article\":{\"subject\":\"Host Bot Telegram - DOWN\",\"body\":\"Termonitor host Bot Telegram - DOWN\n\nHost: $HOSTNAME\nIP: $HOSTADDRESS\nState: $HOSTSTATE\n\nAdditional Info :\n$HOSTOUTPUT\"},\"customer_id\":$CUSTOMER_ID}" \
            "$ZAMMAD_URL/tickets.json")

        TICKET_NUMBER=$(echo "$TICKET_RESPONSE" | jq -r '.number')
        TICKET_TITLE=$(echo "$TICKET_RESPONSE" | jq -r '.title')

        echo "$(date '+%Y-%m-%d %H:%M:%S') - Membuat tiket baru untuk Host Bot Telegram dengan state DOWN. Nomor Tiket: $TICKET_NUMBER, Judul Tiket: $TICKET_TITLE, state hardcode: $(state_id_open), state id: $(get_last_ticket_info)" >> "$LOG_FILE"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Tiket sudah ada untuk Host Bot Telegram dengan state DOWN. Tidak membuat tiket baru." >> "$LOG_FILE"
    fi
}

# Membuat tiket baru
create_ticket
