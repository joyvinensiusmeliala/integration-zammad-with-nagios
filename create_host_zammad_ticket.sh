#!/bin/bash

ZAMMAD_TOKEN="oIe12Gjw_F0Xm5byX6qRRTLH_6glomQW9Zdn03e9xi0"
ZAMMAD_URL="http://192.168.30.187:81"

NOTIFICATIONTYPE="$1"
HOSTNAME="$2"
HOSTADDRESS="$3"
HOSTSTATE="$4"
HOSTOUTPUT="$5"

# Fungsi untuk mendapatkan ID tiket terakhir berdasarkan subjek
get_last_ticket_id() {
    curl -s -H "Authorization: Bearer $ZAMMAD_TOKEN" "$ZAMMAD_URL/api/v1/tickets/search?query=article.subject:\"Host $HOSTNAME - $HOSTSTATE\"" | jq -r '.[0].id'
}

# Fungsi untuk mendapatkan status host terakhir
get_last_host_status() {
    curl -s -H "Authorization: Bearer $ZAMMAD_TOKEN" "$ZAMMAD_URL/api/v1/hosts/search?query=name:$HOSTNAME" | jq -r '.[0].state'
}

# Fungsi untuk membuat tiket baru atau menambahkan artikel baru ke tiket yang sudah ada
create_ticket() {
    CUSTOMER_ID=$(curl -s -H "Authorization: Bearer $ZAMMAD_TOKEN" "$ZAMMAD_URL/api/v1/users/search?query=soc.monitoring@privy.id" | jq -r '.[0].id')

    HOST_INFO="$HOSTNAME"
    IP_INFO="$HOSTADDRESS"
    STATE_INFO="$HOSTSTATE"
    ADDITIONAL_INFO="$HOSTOUTPUT"

    # Cari ID tiket terakhir berdasarkan subjek
    LAST_TICKET_ID=$(get_last_ticket_id)

    if [ -n "$LAST_TICKET_ID" ]; then
        LAST_TICKET_STATUS=$(curl -s -H "Authorization: Bearer $ZAMMAD_TOKEN" "$ZAMMAD_URL/api/v1/tickets/$LAST_TICKET_ID" | jq -r '.state')
        if [ "$LAST_TICKET_STATUS" != "closed" ]; then
            # Tiket terakhir masih terbuka
            echo "Tiket terakhir masih terbuka. Tidak membuat tiket baru."
        else
            # Tiket terakhir sudah ditutup, buat tiket baru
            create_new_ticket
        fi
    else
        # Tiket belum ada, buat tiket baru
        create_new_ticket
    fi
}

# Fungsi untuk membuat tiket baru
create_new_ticket() {
    curl -X POST \
        -H "Authorization: Bearer $ZAMMAD_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"title\":\"Termonitor host $HOSTNAME - $HOSTSTATE\",\"group\":\"Users\",\"article\":{\"subject\":\"Host $HOSTNAME - $HOSTSTATE\",\"body\":\"Termonitor host $HOSTNAME - $HOSTSTATE\n\nHost: $HOSTNAME\nIP: $HOSTADDRESS\nState: $HOSTSTATE\n\nAdditional Info :\n$ADDITIONAL_INFO\"},\"customer_id\":$CUSTOMER_ID}" \
        "$ZAMMAD_URL/api/v1/tickets.json"
}

# Periksa apakah host memiliki status yang sama dengan tiket terakhir
LAST_HOST_STATUS=$(get_last_host_status)

if [ "$NOTIFICATIONTYPE" == "PROBLEM" ] && [ "$LAST_HOST_STATUS" != "$HOSTSTATE" ]; then
    # Jika jenis notifikasi adalah "PROBLEM" dan host memiliki status berbeda, buat tiket baru atau tambahkan artikel baru ke tiket yang sudah ada
    create_ticket
fi
