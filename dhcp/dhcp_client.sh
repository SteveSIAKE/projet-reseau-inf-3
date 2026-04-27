#!/bin/bash
# ============================================================
#  dhcp_client.sh — Client DHCP simplifié en Shell
#  Compatible avec les fichiers d'état de dhcp_server.sh
#  Projet Réseau & SE — Protocoles en Shell
# ============================================================

source "$(dirname "$0")/../utils/logger.sh"

POOL_FILE="/tmp/dhcp_pool.txt"
BAUX_FILE="/tmp/dhcp_baux.txt"
CONF_FILE="/tmp/dhcp_config.txt"
CLIENT_STATE_FILE="/tmp/dhcp_client_state.txt"

CLIENT_MAC="${1:-$(printf '%02X:%02X:%02X:%02X:%02X:%02X' \
    $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) \
    $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))}"
CLIENT_HOSTNAME="${2:-client-$(echo "$CLIENT_MAC" | tr -d ':' | tail -c 5)}"

SERVEUR_IP=""
MASQUE=""
PASSERELLE=""
DNS_PRIMAIRE=""
DUREE_BAIL=""
IP_CLIENT=""

charger_config() {
    if [ ! -f "$CONF_FILE" ]; then
        log_error "Configuration serveur introuvable : $CONF_FILE"
        log_info "Lance d'abord ./dhcp_server.sh pour initialiser le serveur."
        return 1
    fi

    # shellcheck source=/dev/null
    source "$CONF_FILE"
    return 0
}

obtenir_ip_libre() {
    awk '$1=="LIBRE" {print $2; exit}' "$POOL_FILE" 2>/dev/null
}

reserver_ip() {
    local ip="$1"
    sed -i "s/^LIBRE $ip$/RESERVE $ip/" "$POOL_FILE"
}

attribuer_ip() {
    local ip="$1"
    sed -i "s/^RESERVE $ip$/ATTRIBUE $ip/" "$POOL_FILE"
}

liberer_ip() {
    local ip="$1"
    sed -i "s/^ATTRIBUE $ip$/LIBRE $ip/" "$POOL_FILE"
    sed -i "s/^RESERVE $ip$/LIBRE $ip/" "$POOL_FILE"
}

trouver_bail_actif_ip() {
    local mac="$1"
    awk -F'|' -v m="$mac" '
        $1 ~ "^"m" " && $6 ~ /ACTIF/ {
            gsub(/ /, "", $2);
            print $2;
            exit
        }' "$BAUX_FILE" 2>/dev/null
}

ajouter_bail() {
    local mac="$1" ip="$2" host="$3"
    local debut expiration
    debut=$(date '+%Y-%m-%d %H:%M:%S')
    expiration=$(date -d "+${DUREE_BAIL} seconds" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || \
                 date -v "+${DUREE_BAIL}S" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || \
                 echo "$(date '+%Y-%m-%d') 23:59:59")
    echo "$mac | $ip | $host | $debut | $expiration | ACTIF" >> "$BAUX_FILE"
}

mettre_a_jour_etat_client() {
    local ip="$1"
    cat > "$CLIENT_STATE_FILE" << EOF
MAC=$CLIENT_MAC
HOSTNAME=$CLIENT_HOSTNAME
IP_CLIENT=$ip
SERVEUR_IP=$SERVEUR_IP
MASQUE=$MASQUE
PASSERELLE=$PASSERELLE
DNS_PRIMAIRE=$DNS_PRIMAIRE
DUREE_BAIL=$DUREE_BAIL
EOF
}

charger_etat_client() {
    if [ -f "$CLIENT_STATE_FILE" ]; then
        # shellcheck source=/dev/null
        source "$CLIENT_STATE_FILE"
        return 0
    fi
    return 1
}

envoyer_discover() {
    local ip_offerte
    ip_offerte=$(trouver_bail_actif_ip "$CLIENT_MAC")

    if [ -z "$ip_offerte" ]; then
        ip_offerte=$(obtenir_ip_libre)
        if [ -z "$ip_offerte" ]; then
            echo "NAK|Pool épuisé"
            return 1
        fi
        reserver_ip "$ip_offerte"
    fi

    echo "OFFER|$ip_offerte|$MASQUE|$PASSERELLE|$DNS_PRIMAIRE|$DUREE_BAIL|$SERVEUR_IP"
}

envoyer_request() {
    local ip_demandee="$1"
    local statut
    statut=$(awk -v ip="$ip_demandee" '$2==ip {print $1; exit}' "$POOL_FILE")

    if [ "$statut" = "RESERVE" ] || [ "$statut" = "ATTRIBUE" ]; then
        attribuer_ip "$ip_demandee"
        ajouter_bail "$CLIENT_MAC" "$ip_demandee" "$CLIENT_HOSTNAME"
        echo "ACK|$ip_demandee|$MASQUE|$PASSERELLE|$DNS_PRIMAIRE|$DUREE_BAIL|$SERVEUR_IP"
    else
        echo "NAK|IP non disponible"
        return 1
    fi
}

envoyer_release() {
    local ip="$1"
    liberer_ip "$ip"
    if [ -f "$BAUX_FILE" ]; then
        sed -i "s/$CLIENT_MAC | $ip | .* | ACTIF/$CLIENT_MAC | $ip | $CLIENT_HOSTNAME | - | - | LIBERE/" "$BAUX_FILE"
    fi
}

dora() {
    clear
    banner "CLIENT DHCP — PROCESSUS DORA"

    log_client "Identité : MAC=$CLIENT_MAC | HOST=$CLIENT_HOSTNAME"
    separator
    echo ""

    log_step 1 "DHCP DISCOVER"
    local offer
    offer=$(envoyer_discover)
    if echo "$offer" | grep -q "^NAK"; then
        log_error "$(echo "$offer" | cut -d'|' -f2)"
        return 1
    fi

    IFS='|' read -r _ IP_CLIENT MASQUE PASSERELLE DNS_PRIMAIRE DUREE_BAIL SERVEUR_IP <<< "$offer"
    IP_CLIENT=$(echo "$IP_CLIENT" | tr -d ' ')
    log_recv "DHCPOFFER : IP proposée = $IP_CLIENT"
    sleep 0.4

    log_step 2 "DHCP REQUEST"
    local ack
    ack=$(envoyer_request "$IP_CLIENT")
    if echo "$ack" | grep -q "^NAK"; then
        log_error "$(echo "$ack" | cut -d'|' -f2)"
        return 1
    fi

    IFS='|' read -r _ IP_CLIENT MASQUE PASSERELLE DNS_PRIMAIRE DUREE_BAIL SERVEUR_IP <<< "$ack"
    IP_CLIENT=$(echo "$IP_CLIENT" | tr -d ' ')
    mettre_a_jour_etat_client "$IP_CLIENT"

    log_success "DHCPACK reçu, configuration appliquée"
    printf "  ${CYAN}%-14s${NC}: ${GREEN}%s${NC}\n" "Adresse IP" "$IP_CLIENT"
    printf "  ${CYAN}%-14s${NC}: ${GREEN}%s${NC}\n" "Masque" "$MASQUE"
    printf "  ${CYAN}%-14s${NC}: ${GREEN}%s${NC}\n" "Passerelle" "$PASSERELLE"
    printf "  ${CYAN}%-14s${NC}: ${GREEN}%s${NC}\n" "DNS" "$DNS_PRIMAIRE"
    printf "  ${CYAN}%-14s${NC}: ${GREEN}%s s${NC}\n" "Durée bail" "$DUREE_BAIL"
    echo ""
}

release_bail() {
    clear
    banner "CLIENT DHCP — RELEASE"

    if ! charger_etat_client || [ -z "${IP_CLIENT:-}" ]; then
        log_warn "Aucun bail client local trouvé."
        log_info "Exécute d'abord un DORA complet."
        return 1
    fi

    log_step 1 "DHCP RELEASE pour $IP_CLIENT"
    envoyer_release "$IP_CLIENT"
    rm -f "$CLIENT_STATE_FILE"
    log_success "Adresse $IP_CLIENT libérée."
    echo ""
}

afficher_etat() {
    clear
    banner "ETAT DU CLIENT DHCP"
    if charger_etat_client; then
        printf "  ${CYAN}%-14s${NC}: %s\n" "MAC" "$MAC"
        printf "  ${CYAN}%-14s${NC}: %s\n" "Hostname" "$HOSTNAME"
        printf "  ${CYAN}%-14s${NC}: %s\n" "Adresse IP" "$IP_CLIENT"
        printf "  ${CYAN}%-14s${NC}: %s\n" "Serveur DHCP" "$SERVEUR_IP"
        printf "  ${CYAN}%-14s${NC}: %s\n" "Masque" "$MASQUE"
        printf "  ${CYAN}%-14s${NC}: %s\n" "Passerelle" "$PASSERELLE"
        printf "  ${CYAN}%-14s${NC}: %s\n" "DNS" "$DNS_PRIMAIRE"
    else
        log_warn "Aucun état local enregistré."
    fi
    echo ""
}

menu() {
    if ! charger_config; then
        exit 1
    fi

    while true; do
        clear
        banner "CLIENT DHCP — Réseau & Système d'exploitation"
        echo -e "  ${BOLD}Client :${NC} $CLIENT_HOSTNAME (${CYAN}$CLIENT_MAC${NC})"
        echo ""
        echo -e "  ${BOLD}1)${NC} Obtenir une IP (DORA complet)"
        echo -e "  ${BOLD}2)${NC} Libérer le bail (DHCP RELEASE)"
        echo -e "  ${BOLD}3)${NC} Afficher l'état local"
        echo -e "  ${BOLD}0)${NC} Quitter"
        echo ""
        echo -ne "  ${BOLD}Choix :${NC} "
        read -r choix

        case "$choix" in
            1) dora ;;
            2) release_bail ;;
            3) afficher_etat ;;
            0) echo -e "\n${DIM}Au revoir !${NC}\n"; exit 0 ;;
            *) log_error "Choix invalide" ;;
        esac
        echo -ne "  ${DIM}Entrée pour continuer...${NC}"
        read -r
    done
}

menu
