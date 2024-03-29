#!/bin/bash

ZAMMAD_TOKEN="oIe12Gjw_F0Xm5byX6qRRTLH_6glomQW9Zdn03e9xi0"
ZAMMAD_URL="http://192.168.30.187:81/api/v1"
LOG_FILE="/usr/local/nagios/libexec/log_zammad_ticket.txt"

NOTIFICATIONTYPE="$1"
HOSTNAME="$2"
HOSTADDRESS="$3"
HOSTSTATE="$4"
HOSTOUTPUT="$5"


# Mengambil tiket terbaru dengan judul "Termonitor host Bot Telegram - DOWN" dan menampilkan judul dan state_id
get_last_ticket_info() {
    query="Termonitor host $HOSTNAME - $HOSTSTATE"
    encoded_query=$(printf "%s" "$query" | jq -s -R -r @uri)
    
    curl_output=$(curl -s -X GET -H "Authorization: Bearer $ZAMMAD_TOKEN" "$ZAMMAD_URL/tickets?query=article.title:$encoded_query")
    state_id=$(echo "$curl_output" | jq -r ".[] | select(.title == \"$query\") | .state_id" | tail -n 1)
    
    echo "$state_id"
}

state_id_open() {
    echo 2;
}

# Fungsi untuk membuat tiket baru
create_ticket() {
    CUSTOMER_ID=$(curl -s -H "Authorization: Bearer $ZAMMAD_TOKEN" "$ZAMMAD_URL/users/search?query=soc.monitoring@privy.id" | jq -r '.[0].id')

    # Buat tiket baru hanya jika tiket terakhir untuk host tersebut tidak dalam status "open" (state_id=2)
    if [ "$(get_last_ticket_info)" != "$(state_id_open)" ]; then
        TICKET_RESPONSE=$(curl -s -X POST \
            -H "Authorization: Bearer $ZAMMAD_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"title\":\"Termonitor host $HOSTNAME - $HOSTSTATE\",\"group\":\"Users\",\"state_id\":2,\"article\":{\"subject\":\"Host $HOSTNAME - $HOSTSTATE\",\"body\":\"Termonitor host $HOSTNAME - $HOSTSTATE\n\nHost: $HOSTNAME\nIP: $HOSTADDRESS\nState: $HOSTSTATE\n\nAdditional Info :\n$HOSTOUTPUT\"},\"customer_id\":$CUSTOMER_ID}" \
            "$ZAMMAD_URL/tickets.json")

        # Ekstrak ticket number dan title dari respons JSON
        TICKET_NUMBER=$(echo "$TICKET_RESPONSE" | jq -r '.number')
        TICKET_TITLE=$(echo "$TICKET_RESPONSE" | jq -r '.title')

        # Cetak status tiket terbaru, nomor tiket, dan judul tiket
        echo "Update Informasi ($(date '+%Y-%m-%d %H:%M:%S')):" >> "$LOG_FILE"
        echo "Membuat tiket baru untuk : $TICKET_TITLE, Nomor Tiket: $TICKET_NUMBER" >> "$LOG_FILE"
        echo "status tiket terakhir = $(get_last_ticket_info)" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"  # Baris kosong untuk log selanjutnya
    else
        # Jika tiket sudah ada dalam status "open", cetak pesan bahwa tiket tidak perlu dibuat lagi
        echo "Update Informasi ($(date '+%Y-%m-%d %H:%M:%S')):" >> "$LOG_FILE"
        echo "Tiket sudah ada untuk Host $HOSTNAME dengan state $HOSTSTATE. Tidak membuat tiket baru." >> "$LOG_FILE"
        echo "status tiket terakhir = $(get_last_ticket_info)" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"  # Baris kosong untuk log selanjutnya
    fi
}

# Memanggil fungsi untuk mendapatkan informasi terakhir dari tiket
LAST_TICKET_INFO=$(get_last_ticket_info)
LAST_TICKET_STATE=$(echo "$LAST_TICKET_INFO" | jq -r '.state_id')

# Membuat tiket baru
create_ticket
