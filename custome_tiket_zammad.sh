#!/bin/bash

ZAMMAD_TOKEN="oIe12Gjw_F0Xm5byX6qRRTLH_6glomQW9Zdn03e9xi0"
ZAMMAD_URL="http://192.168.30.187:81/api/v1"
LOG_FILE="/usr/local/nagios/libexec/log_zammad_ticket.txt"

NOTIFICATIONTYPE="$1"
HOSTNAME="$2"
HOSTADDRESS="$3"
HOSTSTATE="$4"
HOSTOUTPUT="$5"

# Nama file untuk lock file
LOCKFILE=/tmp/lockfile

if [ -e ${LOCKFILE} ] && kill -0 cat ${LOCKFILE}; then
    echo "Skrip sudah berjalan"
    exit
fi

# Membuat lock file
echo $$ > ${LOCKFILE}

# Memastikan lock file dihapus saat skrip selesai
trap "rm -f ${LOCKFILE}; exit" INT TERM EXIT

# Fungsi untuk mendapatkan informasi hostname dan state_id dari tiket terakhir yang sesuai dengan host Mikrotik CHR Sentul
get_last_ticket_info() {
    response=$(curl -s -X GET -H "Authorization: Bearer $ZAMMAD_TOKEN" "$ZAMMAD_URL/tickets?query=article.subject:Mikrotik%20CHR%20Sentul")
    last_ticket=$(echo "$response" | jq -r '.[-1]')
    hostname=$(echo "$last_ticket" | jq -r '.title')
    state_id=$(echo "$last_ticket" | jq -r '.state_id')
    echo "{\"hostname\": \"$hostname\", \"state_id\": \"$state_id\"}"
}

# Fungsi untuk membuat tiket baru
create_ticket() {
    CUSTOMER_ID=$(curl -s -H "Authorization: Bearer $ZAMMAD_TOKEN" "$ZAMMAD_URL/users/search?query=soc.monitoring@privy.id" | jq -r '.[0].id')

    # Buat tiket baru hanya jika tiket terakhir untuk host tersebut tidak dalam status "open" (state_id=2)
    if [ "$LAST_TICKET_STATE" != "2" ]; then
        TICKET_RESPONSE=$(curl -s -X POST \
            -H "Authorization: Bearer $ZAMMAD_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"title\":\"Termonitor host $HOSTNAME - $HOSTSTATE\",\"group\":\"Users\",\"state_id\":2,\"article\":{\"subject\":\"Host $HOSTNAME - $HOSTSTATE\",\"body\":\"Termonitor host $HOSTNAME - $HOSTSTATE\n\nHost: $HOSTNAME\nIP: $HOSTADDRESS\nState: $HOSTSTATE\n\nAdditional Info :\n$HOSTOUTPUT\"},\"customer_id\":$CUSTOMER_ID}" \
            "$ZAMMAD_URL/tickets.json")

        # Ekstrak ticket number dan title dari respons JSON
        TICKET_NUMBER=$(echo "$TICKET_RESPONSE" | jq -r '.number')
        TICKET_TITLE=$(echo "$TICKET_RESPONSE" | jq -r '.title')

        # Cetak status tiket terbaru, nomor tiket, dan judul tiket
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Membuat tiket baru untuk Host $HOSTNAME dengan state $HOSTSTATE. Nomor Tiket: $TICKET_NUMBER, Judul Tiket: $TICKET_TITLE" >> "$LOG_FILE"
    else
        # Jika tiket sudah ada dalam status "open", cetak pesan bahwa tiket tidak perlu dibuat lagi
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Tiket sudah ada untuk Host $HOSTNAME dengan state $HOSTSTATE. Tidak membuat tiket baru." >> "$LOG_FILE"
    fi
}

# Memanggil fungsi untuk mendapatkan informasi terakhir dari tiket
LAST_TICKET_INFO=$(get_last_ticket_info)
LAST_TICKET_STATE=$(echo "$LAST_TICKET_INFO" | jq -r '.state_id')

# Membuat tiket baru
create_ticket

# Menghapus lock file
rm -f ${LOCKFILE}
