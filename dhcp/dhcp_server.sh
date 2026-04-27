# Serveur DHCP simplifié (pool d'adresses, baux)
# Le serveur DHCP écoute les requêtes des clients DHCP sur le port 67 (UDP).
# Lorsqu'il reçoit une requête de découverte (DHCPDISCOVER) d'un client DHCP, il vérifie son pool d'adresses disponibles et propose une adresse IP au client en envoyant une offre (DHCPOFFER) contenant l'adresse IP proposée et d'autres informations de configuration.
# Si le client DHCP accepte l'offre en envoyant une requête de demande (DHCPREQUEST), le serveur DHCP attribue l'adresse IP au client et envoie une confirmation (DHCP  ACK) pour finaliser le processus de configuration de l'adresse IP.  
# Le serveur DHCP maintient également un registre des baux d'adresses IP attribuées aux clients, avec des informations telles que l'adresse MAC du client, l'adresse IP attribuée, la durée du bail, etc.
#!/bin/bash
# ============================================================
#  dhcp_server.sh — Serveur DHCP simplifié en Shell
#  Pool d'adresses, gestion des baux, interface interactive
#  Projet Réseau & SE — Protocoles en Shell
# ============================================================

source "$(dirname "$0")/../utils/logger.sh"
 
# ────────────────────────────────────────────── ──────────────
# Configuration du serveur
# ────────────────────────────────────────────────────────────

SERVEUR_IP="192.168.1.1"
RESEAU="192.168.1"
POOL_DEBUT=100
POOL_FIN=200
MASQUE="255.255.255.0"
PASSERELLE="192.168.1.1"
DNS_PRIMAIRE="8.8.8.8"
DNS_SECONDAIRE="8.8.4.4"
DUREE_BAIL=86400       # 24h
DUREE_BAIL_COURT=3600  # 1h (pour la démo)

# Fichiers d'état
POOL_FILE="/tmp/dhcp_pool.txt"
BAUX_FILE="/tmp/dhcp_baux.txt"
LOG_DHCP="/tmp/dhcp_server.log"
CONF_FILE="/tmp/dhcp_config.txt"

# ────────────────────────────────────────────────────────────
# Initialisation
# ────────────────────────────────────────────────────────────

initialiser() {
    # Créer le pool d'adresses
    > "$POOL_FILE"
    for i in $(seq $POOL_DEBUT $POOL_FIN); do
        echo "LIBRE ${RESEAU}.${i}" >> "$POOL_FILE"
    done

    # Créer le fichier des baux (vide)
    echo "# MAC | IP | HOSTNAME | DEBUT | EXPIRATION | STATUT" > "$BAUX_FILE"

    # Écrire la configuration
    cat > "$CONF_FILE" << EOF
SERVEUR_IP=$SERVEUR_IP
RESEAU=$RESEAU
POOL_DEBUT=$POOL_DEBUT
POOL_FIN=$POOL_FIN
MASQUE=$MASQUE
PASSERELLE=$PASSERELLE
DNS_PRIMAIRE=$DNS_PRIMAIRE
DNS_SECONDAIRE=$DNS_SECONDAIRE
DUREE_BAIL=$DUREE_BAIL
EOF

    log_success "Serveur DHCP initialisé"
    log_info "Pool : ${RESEAU}.${POOL_DEBUT} → ${RESEAU}.${POOL_FIN} ($(( POOL_FIN - POOL_DEBUT + 1 )) adresses)"
}

# ────────────────────────────────────────────────────────────
# Obtenir une IP libre du pool
# ────────────────────────────────────────────────────────────

obtenir_ip_libre() {
    grep "^LIBRE" "$POOL_FILE" | head -1 | awk '{print $2}'
}

# ────────────────────────────────────────────────────────────
# Réserver une IP dans le pool
# ────────────────────────────────────────────────────────────

reserver_ip() {
    local ip="$1"
    sed -i "s/^LIBRE $ip$/RESERVE $ip/" "$POOL_FILE"
}

# ────────────────────────────────────────────────────────────
# Libérer une IP dans le pool
# ────────────────────────────────────────────────────────────

liberer_ip() {
    local ip="$1"
    sed -i "s/^RESERVE $ip$/LIBRE $ip/" "$POOL_FILE"
    sed -i "s/^ATTRIBUE $ip$/LIBRE $ip/" "$POOL_FILE"
}

# ────────────────────────────────────────────────────────────
# Ajouter un bail
# ────────────────────────────────────────────────────────────

ajouter_bail() {
    local mac="$1" ip="$2" hostname="$3"
    local debut expiration
    debut=$(date '+%Y-%m-%d %H:%M:%S')
    expiration=$(date -d "+${DUREE_BAIL} seconds" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || \
                 date -v "+${DUREE_BAIL}S" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || \
                 echo "$(date '+%Y-%m-%d') 23:59:59")

    echo "$mac | $ip | $hostname | $debut | $expiration | ACTIF" >> "$BAUX_FILE"
    sed -i "s/^RESERVE $ip$/ATTRIBUE $ip/" "$POOL_FILE"
}

# ────────────────────────────────────────────────────────────
# Traitement : DHCP DISCOVER → OFFER
# ────────────────────────────────────────────────────────────

traiter_discover() {
    local mac="$1" hostname="${2:-inconnu}"
    local ts
    ts=$(timestamp)

    log_time "${CYAN}[DISCOVER]${NC} MAC=$mac HOST=$hostname"

    # Vérifier si ce client a déjà un bail actif
    local bail_existant
    bail_existant=$(grep "^$mac" "$BAUX_FILE" | grep "ACTIF" | head -1)

    local ip_offerte
    if [ -n "$bail_existant" ]; then
        ip_offerte=$(echo "$bail_existant" | cut -d'|' -f2 | tr -d ' ')
        log_info "Client connu → on lui re-propose son ancienne IP : $ip_offerte"
    else
        ip_offerte=$(obtenir_ip_libre)
        if [ -z "$ip_offerte" ]; then
            log_error "Pool épuisé ! Aucune IP disponible"
            echo "NAK|Pool épuisé" | tee -a "$LOG_DHCP"
            return 1
        fi
        reserver_ip "$ip_offerte"
    fi

    log_time "${GREEN}[OFFER]${NC}    IP proposée : $ip_offerte → $mac"
    echo "[$ts] DISCOVER mac=$mac host=$hostname" >> "$LOG_DHCP"
    echo "[$ts] OFFER    ip=$ip_offerte mac=$mac" >> "$LOG_DHCP"

    echo "OFFER|$ip_offerte|$MASQUE|$PASSERELLE|$DNS_PRIMAIRE|$DUREE_BAIL|$SERVEUR_IP"
}

# ────────────────────────────────────────────────────────────
# Traitement : DHCP REQUEST → ACK ou NAK
# ────────────────────────────────────────────────────────────

traiter_request() {
    local mac="$1" ip_demandee="$2" hostname="${3:-inconnu}"
    local ts
    ts=$(timestamp)

    log_time "${CYAN}[REQUEST]${NC}  MAC=$mac IP=$ip_demandee HOST=$hostname"

    # Vérifier que l'IP est dans notre pool et réservée pour ce client
    local statut_pool
    statut_pool=$(grep "$ip_demandee" "$POOL_FILE" | awk '{print $1}')

    if [ "$statut_pool" = "RESERVE" ] || [ "$statut_pool" = "ATTRIBUE" ]; then
        # Vérifier si déjà un bail
        local bail_existant
        bail_existant=$(grep "^$mac.*ACTIF" "$BAUX_FILE" 2>/dev/null | head -1)

        if [ -z "$bail_existant" ]; then
            ajouter_bail "$mac" "$ip_demandee" "$hostname"
        else
            # Renouvellement — mettre à jour l'expiration
            sed -i "/$mac/s/ACTIF/RENOUVELE/" "$BAUX_FILE"
            ajouter_bail "$mac" "$ip_demandee" "$hostname"
            sed -i "/$mac.*RENOUVELE/d" "$BAUX_FILE"
        fi

        log_time "${GREEN}[ACK]${NC}      IP confirmée : $ip_demandee → $mac"
        echo "[$ts] REQUEST  ip=$ip_demandee mac=$mac" >> "$LOG_DHCP"
        echo "[$ts] ACK      ip=$ip_demandee mac=$mac" >> "$LOG_DHCP"

        echo "ACK|$ip_demandee|$MASQUE|$PASSERELLE|$DNS_PRIMAIRE|$DUREE_BAIL|$SERVEUR_IP"
    else
        log_warn "IP $ip_demandee non disponible ou non réservée pour $mac"
        echo "[$ts] REQUEST  ip=$ip_demandee mac=$mac" >> "$LOG_DHCP"
        echo "[$ts] NAK      ip=$ip_demandee mac=$mac raison=non_disponible" >> "$LOG_DHCP"
        echo "NAK|IP non disponible"
    fi
}

# ────────────────────────────────────────────────────────────
# Traitement : DHCP RELEASE
# ────────────────────────────────────────────────────────────

traiter_release() {
    local mac="$1" ip="$2"
    local ts
    ts=$(timestamp)

    log_time "${YELLOW}[RELEASE]${NC}  MAC=$mac libère $ip"
    liberer_ip "$ip"
    sed -i "s/$mac.*ACTIF/$mac | $ip | - | - | - | LIBERE/" "$BAUX_FILE"
    echo "[$ts] RELEASE  ip=$ip mac=$mac" >> "$LOG_DHCP"
    log_success "IP $ip remise dans le pool"
}

# ────────────────────────────────────────────────────────────
# Afficher le pool d'adresses
# ────────────────────────────────────────────────────────────

afficher_pool() {
    banner "POOL D'ADRESSES IP"

    local total libres reservees attribuees
    total=$(wc -l < "$POOL_FILE")
    libres=$(grep -c "^LIBRE" "$POOL_FILE")
    reservees=$(grep -c "^RESERVE" "$POOL_FILE")
    attribuees=$(grep -c "^ATTRIBUE" "$POOL_FILE")

    echo -e "  ${BOLD}Réseau :${NC} ${RESEAU}.0/${MASQUE}"
    echo ""

    # Statistiques
    echo -e "${WHITE}┌──────────────────────────────────────────────┐${NC}"
    printf "${WHITE}│${NC}  ${GREEN}Libres     :${NC} %-5s  ${WHITE}│${NC}  ${YELLOW}Réservées  :${NC} %-5s ${WHITE}│${NC}\n" \
           "$libres" "$reservees"
    printf "${WHITE}│${NC}  ${CYAN}Attribuées :${NC} %-5s  ${WHITE}│${NC}  ${DIM}Total      :${NC} %-5s ${WHITE}│${NC}\n" \
           "$attribuees" "$total"
    echo -e "${WHITE}└──────────────────────────────────────────────┘${NC}"
    echo ""

    # Barre visuelle
    local pct_utilise=$(( (attribuees * 100) / total ))
    local barres=$(( pct_utilise / 5 ))
    echo -ne "  Utilisation : ["
    for ((i=0; i<20; i++)); do
        if [ $i -lt $barres ]; then
            echo -ne "${RED}█${NC}"
        else
            echo -ne "${GREEN}░${NC}"
        fi
    done
    echo "] ${pct_utilise}%"
    echo ""

    # Afficher les 15 premières entrées
    echo -e "  ${DIM}(Affichage des 20 premières entrées)${NC}"
    echo ""
    echo -e "${WHITE}  ┌──────────────────┬────────────┐${NC}"
    echo -e "${WHITE}  │${NC} ${BOLD}Adresse IP        ${WHITE}│${NC} ${BOLD}Statut      ${WHITE}│${NC}"
    echo -e "${WHITE}  ├──────────────────┼────────────┤${NC}"
    head -20 "$POOL_FILE" | while read -r statut ip; do
        case "$statut" in
            LIBRE)    couleur="$GREEN" ;;
            RESERVE)  couleur="$YELLOW" ;;
            ATTRIBUE) couleur="$RED" ;;
            *)        couleur="$NC" ;;
        esac
        printf "${WHITE}  │${NC} ${CYAN}%-16s${NC} ${WHITE}│${NC} ${couleur}%-10s${NC} ${WHITE}│${NC}\n" "$ip" "$statut"
    done
    echo -e "${WHITE}  └──────────────────┴────────────┘${NC}"
    echo ""
}

# ────────────────────────────────────────────────────────────
# Afficher les baux actifs
# ────────────────────────────────────────────────────────────

afficher_baux() {
    banner "BAUX DHCP ACTIFS"

    local nb
    nb=$(grep -c "ACTIF" "$BAUX_FILE" 2>/dev/null || echo 0)
    echo -e "  ${BOLD}Baux actifs :${NC} ${GREEN}$nb${NC}"
    echo ""

    if [ "$nb" -eq 0 ]; then
        log_warn "Aucun bail actif pour le moment"
        return
    fi

    echo -e "${WHITE}┌──────────────────┬─────────────────┬──────────────┬──────────────────────┐${NC}"
    echo -e "${WHITE}│${BOLD} MAC              ${WHITE}│${BOLD} IP              ${WHITE}│${BOLD} Hostname     ${WHITE}│${BOLD} Expiration           ${WHITE}│${NC}"
    echo -e "${WHITE}├──────────────────┼─────────────────┼──────────────┼──────────────────────┤${NC}"

    grep "ACTIF" "$BAUX_FILE" | while IFS='|' read -r mac ip host debut exp statut; do
        printf "${WHITE}│${NC} ${CYAN}%-16s${NC} ${WHITE}│${NC} ${GREEN}%-15s${NC} ${WHITE}│${NC} ${YELLOW}%-12s${NC} ${WHITE}│${NC} ${DIM}%-20s${NC} ${WHITE}│${NC}\n" \
               "$(echo "$mac" | tr -d ' ')" \
               "$(echo "$ip" | tr -d ' ')" \
               "$(echo "$host" | tr -d ' ')" \
               "$(echo "$exp" | tr -d ' ')"
    done

    echo -e "${WHITE}└──────────────────┴─────────────────┴──────────────┴──────────────────────┘${NC}"
    echo ""
}

# ────────────────────────────────────────────────────────────
# Simulation interactive d'échange DHCP
# ────────────────────────────────────────────────────────────

simuler_client() {
    banner "SIMULATION D'UN CLIENT DHCP"

    echo -ne "  MAC du client (Enter = aléatoire) : "
    read -r mac
    [ -z "$mac" ] && mac=$(printf '%02X:%02X:%02X:%02X:%02X:%02X' \
        $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) \
        $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))

    echo -ne "  Nom d'hôte                        : "
    read -r host
    [ -z "$host" ] && host="Client-$(echo "$mac" | cut -d: -f5-6 | tr -d ':')"

    echo ""
    log_client "=== Début processus DORA pour $host ($mac) ==="
    echo ""

    # DISCOVER → OFFER
    log_step 1 "Envoi DHCP DISCOVER..."
    sleep 0.5
    local offer
    offer=$(traiter_discover "$mac" "$host")
    echo ""

    if echo "$offer" | grep -q "^NAK"; then
        log_error "Serveur : $(echo "$offer" | cut -d'|' -f2)"
        return
    fi

    local ip_offerte
    ip_offerte=$(echo "$offer" | cut -d'|' -f2)
    log_recv "DHCP OFFER reçu : IP proposée = ${GREEN}$ip_offerte${NC}"
    echo ""
    sleep 0.5

    # REQUEST → ACK
    log_step 2 "Envoi DHCP REQUEST pour $ip_offerte..."
    sleep 0.5
    local ack
    ack=$(traiter_request "$mac" "$ip_offerte" "$host")
    echo ""

    if echo "$ack" | grep -q "^ACK"; then
        log_success "DHCP ACK reçu ! Configuration appliquée :"
        echo ""
        IFS='|' read -r _ ip masque gw dns bail srv <<< "$ack"
        printf "  ${CYAN}%-18s${NC} : ${GREEN}%s${NC}\n" "Adresse IP"    "$(echo $ip | tr -d ' ')"
        printf "  ${CYAN}%-18s${NC} : ${GREEN}%s${NC}\n" "Masque"        "$(echo $masque | tr -d ' ')"
        printf "  ${CYAN}%-18s${NC} : ${GREEN}%s${NC}\n" "Passerelle"    "$(echo $gw | tr -d ' ')"
        printf "  ${CYAN}%-18s${NC} : ${GREEN}%s${NC}\n" "DNS"           "$(echo $dns | tr -d ' ')"
        printf "  ${CYAN}%-18s${NC} : ${GREEN}%s${NC}\n" "Durée bail"    "$(echo $bail | tr -d ' ')s"
    elif echo "$ack" | grep -q "^NAK"; then
        log_error "DHCP NAK reçu : $(echo "$ack" | cut -d'|' -f2)"
        log_info "Le client relancera un DISCOVER..."
    fi
    echo ""
}

# ────────────────────────────────────────────────────────────
# Réservation statique
# ────────────────────────────────────────────────────────────

reserver_statique() {
    banner "RÉSERVATION STATIQUE DHCP"

    echo -e "  ${DIM}Associe une IP fixe à une adresse MAC (toujours la même IP)${NC}"
    echo ""
    echo -ne "  Adresse MAC : "; read -r mac
    echo -ne "  IP à réserver (ex: ${RESEAU}.50) : "; read -r ip
    echo -ne "  Nom d'hôte   : "; read -r host
    [ -z "$host" ] && host="StaticHost"

    # Marquer l'IP comme réservée statiquement dans le pool
    if grep -q "$ip" "$POOL_FILE"; then
        sed -i "s/.*$ip$/STATIC $ip/" "$POOL_FILE"
        echo "$mac | $ip | $host (STATIQUE) | $(date '+%Y-%m-%d %H:%M:%S') | permanent | ACTIF" \
            >> "$BAUX_FILE"
        log_success "Réservation statique : $mac → $ip ($host)"
    else
        log_error "L'IP $ip n'est pas dans le pool ${RESEAU}.${POOL_DEBUT}-${RESEAU}.${POOL_FIN}"
    fi
    echo ""
}

# ────────────────────────────────────────────────────────────
# Afficher les logs
# ────────────────────────────────────────────────────────────

afficher_logs() {
    banner "LOGS DU SERVEUR DHCP"
    if [ -f "$LOG_DHCP" ] && [ -s "$LOG_DHCP" ]; then
        tail -30 "$LOG_DHCP" | while IFS= read -r ligne; do
            if echo "$ligne" | grep -q "DISCOVER"; then
                echo -e "${CYAN}$ligne${NC}"
            elif echo "$ligne" | grep -q "OFFER\|ACK"; then
                echo -e "${GREEN}$ligne${NC}"
            elif echo "$ligne" | grep -q "NAK\|DECLINE"; then
                echo -e "${RED}$ligne${NC}"
            elif echo "$ligne" | grep -q "RELEASE"; then
                echo -e "${YELLOW}$ligne${NC}"
            else
                echo -e "${DIM}$ligne${NC}"
            fi
        done
    else
        log_warn "Aucun log disponible"
    fi
    echo ""
}

# ────────────────────────────────────────────────────────────
# Menu principal
# ────────────────────────────────────────────────────────────

menu() {
    clear
    banner "SERVEUR DHCP — Réseau & Système d'exploitation"
    echo -e "  ${BOLD}Serveur :${NC} ${GREEN}$SERVEUR_IP${NC} | Pool : ${CYAN}${RESEAU}.${POOL_DEBUT}${NC} → ${CYAN}${RESEAU}.${POOL_FIN}${NC}"
    echo ""
    echo -e "  ${BOLD}1)${NC} Simuler un client DHCP       (processus DORA)"
    echo -e "  ${BOLD}2)${NC} Afficher le pool d'adresses"
    echo -e "  ${BOLD}3)${NC} Afficher les baux actifs"
    echo -e "  ${BOLD}4)${NC} Réservation statique          (MAC → IP fixe)"
    echo -e "  ${BOLD}5)${NC} Afficher les logs serveur"
    echo -e "  ${BOLD}6)${NC} Réinitialiser le serveur"
    echo -e "  ${BOLD}0)${NC} Quitter"
    echo ""
    echo -ne "  ${BOLD}Choix :${NC} "
    read -r choix

    case "$choix" in
        1) simuler_client ;;
        2) afficher_pool ;;
        3) afficher_baux ;;
        4) reserver_statique ;;
        5) afficher_logs ;;
        6) initialiser; log_success "Serveur réinitialisé" ;;
        0) echo -e "\n${DIM}Au revoir !${NC}\n"; exit 0 ;;
        *) log_error "Choix invalide" ;;
    esac

    echo -ne "\n  ${DIM}Appuyez sur Entrée pour continuer...${NC}"
    read -r
    menu
}

# Initialisation et lancement
initialiser
menu