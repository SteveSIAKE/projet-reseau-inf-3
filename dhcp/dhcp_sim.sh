# Simulation visuelle DORA 
#!/bin/bash
# ============================================================
#  dhcp_sim.sh — Simulation visuelle du protocole DHCP
#  Illustre : DORA, renouvellement, libération, NAK, DECLINE
#  Projet Réseau & SE — Protocoles en Shell
# ============================================================
 
source "$(dirname "$0")/../utils/logger.sh"

# ────────────────────────────────────────────────────────────
# Données de simulation
# ────────────────────────────────────────────────────────────

CLIENT_MAC="AA:BB:CC:DD:EE:FF"
CLIENT_HOSTNAME="PC-Etudiant"
SERVEUR_IP="192.168.1.1"
OFFRE_IP="192.168.1.100"
MASQUE="255.255.255.0"
PASSERELLE="192.168.1.1"
DNS_SIM="8.8.8.8"
DUREE_BAIL="86400"   # 24h en secondes

# ────────────────────────────────────────────────────────────
# Affichage d'un paquet DHCP
# ────────────────────────────────────────────────────────────

afficher_paquet() {
    local titre="$1" src="$2" dst="$3"
    shift 3
    echo ""
    echo -e "${WHITE}╔══════════════════════════════════════════════════════╗${NC}"
    printf  "${WHITE}║${BOLD}  %-52s${WHITE}║${NC}\n" "PAQUET DHCP — $titre"
    echo -e "${WHITE}╠══════════════════════════════════════════════════════╣${NC}"
    printf  "${WHITE}║${NC}  %-20s : %-28s ${WHITE}║${NC}\n" "Source"      "$src"
    printf  "${WHITE}║${NC}  %-20s : %-28s ${WHITE}║${NC}\n" "Destination" "$dst"
    printf  "${WHITE}║${NC}  %-20s : %-28s ${WHITE}║${NC}\n" "Transport"   "UDP  67 (serveur) / 68 (client)"
    echo -e "${WHITE}╠══════════════════════════════════════════════════════╣${NC}"
    while [ $# -gt 0 ]; do
        local key="$1" val="$2"
        printf "${WHITE}║${NC}  ${CYAN}%-20s${NC} : ${GREEN}%-28s${NC} ${WHITE}║${NC}\n" "$key" "$val"
        shift 2
    done
    echo -e "${WHITE}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    sleep 0.8
}

fleche_droite() {
    local src="$1" dst="$2" msg="$3" couleur="${4:-$YELLOW}"
    printf "\n  ${CYAN}%-14s${NC} ${couleur}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━→${NC} ${GREEN}%s${NC}\n" "$src" "$dst"
    echo -e "                 ${DIM}$msg${NC}\n"
    sleep 0.7
}

fleche_gauche() {
    local src="$1" dst="$2" msg="$3" couleur="${4:-$YELLOW}"
    printf "\n  ${GREEN}%-14s${NC} ${couleur}←━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC} ${CYAN}%s${NC}\n" "$src" "$dst"
    echo -e "                 ${DIM}$msg${NC}\n"
    sleep 0.7
}

# ────────────────────────────────────────────────────────────
# SIMULATION 1 : Processus DORA complet
# ────────────────────────────────────────────────────────────

simulation_dora() {
    clear
    banner "PROCESSUS DORA — Attribution d'adresse IP par DHCP"

    echo -e "  ${BOLD}DORA${NC} = ${CYAN}D${NC}iscover → ${CYAN}O${NC}ffer → ${CYAN}R${NC}equest → ${CYAN}A${NC}cknowledge"
    echo ""
    echo -e "  ${DIM}Un client qui démarre n'a pas d'adresse IP."
    echo -e "  Il utilise DHCP pour en obtenir une automatiquement.${NC}"
    echo ""
    separator
    sleep 1

    # ── ÉTAPE 1 : DISCOVER ──────────────────────────────────
    echo -e "\n${BOLD}${YELLOW}━━━ ÉTAPE 1 : DHCP DISCOVER ━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "  Le client ${CYAN}$CLIENT_HOSTNAME${NC} démarre."
    echo -e "  Il n'a pas d'IP. Il envoie un broadcast pour trouver un serveur DHCP."
    echo ""

    afficher_paquet "DHCP DISCOVER (Broadcast)" \
        "0.0.0.0:68" "255.255.255.255:67" \
        "Message Type"  "1 (DISCOVER)" \
        "Client MAC"    "$CLIENT_MAC" \
        "Hostname"      "$CLIENT_HOSTNAME" \
        "Transaction ID" "0x3903F326" \
        "Broadcast"     "OUI (flag B=1)"

    fleche_droite "CLIENT" "BROADCAST" \
        "DHCP DISCOVER — Qui peut me donner une IP ?" "$YELLOW"

    # ── ÉTAPE 2 : OFFER ─────────────────────────────────────
    echo -e "\n${BOLD}${GREEN}━━━ ÉTAPE 2 : DHCP OFFER ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "  Le serveur DHCP reçoit le DISCOVER."
    echo -e "  Il réserve l'IP ${GREEN}$OFFRE_IP${NC} et propose une offre."
    echo ""

    afficher_paquet "DHCP OFFER" \
        "$SERVEUR_IP:67" "255.255.255.255:68" \
        "Message Type"  "2 (OFFER)" \
        "IP Proposée"   "$OFFRE_IP" \
        "Masque"        "$MASQUE" \
        "Passerelle"    "$PASSERELLE" \
        "DNS"           "$DNS_SIM" \
        "Durée bail"    "${DUREE_BAIL}s (24h)" \
        "Serveur DHCP"  "$SERVEUR_IP"

    fleche_gauche "CLIENT" "SERVEUR DHCP" \
        "DHCP OFFER — Je t'offre l'IP $OFFRE_IP pour 24h" "$GREEN"

    # ── ÉTAPE 3 : REQUEST ───────────────────────────────────
    echo -e "\n${BOLD}${CYAN}━━━ ÉTAPE 3 : DHCP REQUEST ━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "  Le client accepte l'offre."
    echo -e "  Il broadcast un REQUEST pour confirmer (informe les autres serveurs)."
    echo ""

    afficher_paquet "DHCP REQUEST (Broadcast)" \
        "0.0.0.0:68" "255.255.255.255:67" \
        "Message Type"  "3 (REQUEST)" \
        "IP Demandée"   "$OFFRE_IP" \
        "Serveur DHCP"  "$SERVEUR_IP" \
        "Client MAC"    "$CLIENT_MAC" \
        "Transaction ID" "0x3903F326"

    fleche_droite "CLIENT" "BROADCAST" \
        "DHCP REQUEST — J'accepte l'IP $OFFRE_IP du serveur $SERVEUR_IP" "$CYAN"

    # ── ÉTAPE 4 : ACKNOWLEDGE ───────────────────────────────
    echo -e "\n${BOLD}${MAGENTA}━━━ ÉTAPE 4 : DHCP ACKNOWLEDGE ━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "  Le serveur confirme l'attribution."
    echo -e "  Le client peut maintenant utiliser l'IP ${GREEN}$OFFRE_IP${NC}."
    echo ""

    afficher_paquet "DHCP ACK" \
        "$SERVEUR_IP:67" "255.255.255.255:68" \
        "Message Type"  "5 (ACK)" \
        "IP Attribuée"  "$OFFRE_IP" \
        "Masque"        "$MASQUE" \
        "Passerelle"    "$PASSERELLE" \
        "DNS"           "$DNS_SIM" \
        "Durée bail"    "${DUREE_BAIL}s (24h)" \
        "T1 (50%)"      "43200s — renouvellement" \
        "T2 (87.5%)"    "75600s — rebind"

    fleche_gauche "CLIENT" "SERVEUR DHCP" \
        "DHCP ACK — IP $OFFRE_IP confirmée pour 24h ✓" "$MAGENTA"

    # ── Résultat ────────────────────────────────────────────
    echo ""
    separator
    echo ""
    echo -e "  ${BOLD}✅ Configuration réseau appliquée sur $CLIENT_HOSTNAME :${NC}"
    echo ""
    printf "  ${CYAN}%-18s${NC} : ${GREEN}%s${NC}\n" "Adresse IP"   "$OFFRE_IP"
    printf "  ${CYAN}%-18s${NC} : ${GREEN}%s${NC}\n" "Masque"       "$MASQUE"
    printf "  ${CYAN}%-18s${NC} : ${GREEN}%s${NC}\n" "Passerelle"   "$PASSERELLE"
    printf "  ${CYAN}%-18s${NC} : ${GREEN}%s${NC}\n" "DNS"          "$DNS_SIM"
    printf "  ${CYAN}%-18s${NC} : ${GREEN}%s${NC}\n" "Durée bail"   "24h (expire à $(date -d '+24 hours' '+%H:%M %d/%m/%Y' 2>/dev/null || date -v+24H '+%H:%M %d/%m/%Y' 2>/dev/null))"
    echo ""
}

# ────────────────────────────────────────────────────────────
# SIMULATION 2 : Renouvellement du bail
# ────────────────────────────────────────────────────────────

simulation_renouvellement() {
    clear
    banner "RENOUVELLEMENT DU BAIL DHCP"

    echo -e "  Le bail expire dans ${YELLOW}50%${NC} de sa durée (T1)."
    echo -e "  Le client tente de renouveler son IP ${CYAN}$OFFRE_IP${NC} auprès du même serveur."
    echo ""
    separator
    sleep 1

    echo -e "\n${BOLD}${YELLOW}━━━ Minuteries DHCP ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "  ${CYAN}T1 (50%)${NC}   → Renouvellement avec le serveur d'origine"
    echo -e "  ${YELLOW}T2 (87.5%)${NC} → Rebind (broadcast à n'importe quel serveur)"
    echo -e "  ${RED}Expiration${NC} → Le client perd son IP et relance un DORA"
    echo ""

    # Barre de progression du bail
    echo -e "\n  ${BOLD}Timeline du bail (24h) :${NC}\n"
    echo -e "  ${GREEN}|████████████${YELLOW}░░░░░░░░░░${RED}░░░░░░░░░${NC}|"
    echo -e "  ${DIM}  0h         12h(T1)    21h(T2)   24h${NC}"
    echo ""
    sleep 1

    # Renouvellement unicast à T1
    echo -e "\n${BOLD}━━━ À T1 (12h) : Renouvellement Unicast ━━━━━━━━━━━━━━━${NC}\n"

    afficher_paquet "DHCP REQUEST (Unicast — Renouvellement)" \
        "$OFFRE_IP:68" "$SERVEUR_IP:67" \
        "Message Type"  "3 (REQUEST)" \
        "IP Actuelle"   "$OFFRE_IP" \
        "Serveur DHCP"  "$SERVEUR_IP" \
        "Type"          "Renouvellement (Unicast)"

    fleche_droite "CLIENT ($OFFRE_IP)" "SERVEUR ($SERVEUR_IP)" \
        "Renouvellement : puis-je garder $OFFRE_IP ?" "$CYAN"

    afficher_paquet "DHCP ACK (Renouvellement)" \
        "$SERVEUR_IP:67" "$OFFRE_IP:68" \
        "Message Type"  "5 (ACK)" \
        "IP Confirmée"  "$OFFRE_IP" \
        "Nouveau bail"  "${DUREE_BAIL}s (24h)"

    fleche_gauche "CLIENT ($OFFRE_IP)" "SERVEUR ($SERVEUR_IP)" \
        "Bail renouvelé pour 24h supplémentaires ✓" "$GREEN"

    log_success "Bail renouvelé avec succès !"
    echo ""
}

# ────────────────────────────────────────────────────────────
# SIMULATION 3 : DHCP RELEASE
# ────────────────────────────────────────────────────────────

simulation_release() {
    clear
    banner "DHCP RELEASE — Libération d'adresse IP"

    echo -e "  Le client libère volontairement son IP avant expiration."
    echo -e "  Ex: PC qui s'éteint proprement, changement de réseau."
    echo ""
    separator
    sleep 1

    afficher_paquet "DHCP RELEASE" \
        "$OFFRE_IP:68" "$SERVEUR_IP:67" \
        "Message Type"  "7 (RELEASE)" \
        "IP Libérée"    "$OFFRE_IP" \
        "Client MAC"    "$CLIENT_MAC" \
        "Serveur DHCP"  "$SERVEUR_IP"

    fleche_droite "CLIENT ($OFFRE_IP)" "SERVEUR ($SERVEUR_IP)" \
        "DHCP RELEASE — Je libère l'IP $OFFRE_IP" "$RED"

    echo ""
    log_success "IP $OFFRE_IP libérée et remise dans le pool du serveur"
    echo -e "  ${DIM}Le serveur peut maintenant l'attribuer à un autre client${NC}"
    echo ""
}

# ────────────────────────────────────────────────────────────
# SIMULATION 4 : DHCP NAK (refus du serveur)
# ────────────────────────────────────────────────────────────

simulation_nak() {
    clear
    banner "DHCP NAK — Refus du serveur"

    echo -e "  Le client demande une IP qui n'est plus disponible."
    echo -e "  Le serveur répond avec un ${RED}DHCP NAK${NC} (Negative Acknowledgement)."
    echo ""
    separator
    sleep 1

    afficher_paquet "DHCP REQUEST (IP déjà attribuée)" \
        "0.0.0.0:68" "255.255.255.255:67" \
        "Message Type"  "3 (REQUEST)" \
        "IP Demandée"   "192.168.1.200" \
        "Client MAC"    "$CLIENT_MAC"

    fleche_droite "CLIENT" "BROADCAST" \
        "Je veux récupérer l'IP 192.168.1.200" "$YELLOW"

    afficher_paquet "DHCP NAK (Refus)" \
        "$SERVEUR_IP:67" "255.255.255.255:68" \
        "Message Type"  "6 (NAK)" \
        "Raison"        "IP déjà attribuée ou hors pool" \
        "Message"       "Request declined"

    fleche_gauche "CLIENT" "SERVEUR DHCP" \
        "DHCP NAK — Cette IP n'est pas disponible !" "$RED"

    echo ""
    log_warn "Le client reçoit un NAK → il relance le processus DORA depuis le début"
    echo ""
}

# ────────────────────────────────────────────────────────────
# SIMULATION 5 : DHCP DECLINE
# ────────────────────────────────────────────────────────────

simulation_decline() {
    clear
    banner "DHCP DECLINE — Refus par le client"

    echo -e "  Le client reçoit une offre, mais détecte que l'IP est déjà"
    echo -e "  utilisée sur le réseau (via ARP). Il refuse l'offre."
    echo ""
    separator
    sleep 1

    fleche_gauche "CLIENT" "SERVEUR DHCP" \
        "DHCP OFFER — IP $OFFRE_IP proposée" "$GREEN"

    echo -e "\n  ${YELLOW}[CLIENT]${NC} Vérification ARP : l'IP $OFFRE_IP est-elle libre ?"
    pause "Test ARP en cours"
    echo -e "  ${RED}[ARP]${NC} Réponse reçue ! L'IP $OFFRE_IP est déjà utilisée !"
    echo ""

    afficher_paquet "DHCP DECLINE" \
        "0.0.0.0:68" "255.255.255.255:67" \
        "Message Type"  "4 (DECLINE)" \
        "IP Refusée"    "$OFFRE_IP" \
        "Raison"        "Adresse déjà en cours d'utilisation (ARP)" \
        "Client MAC"    "$CLIENT_MAC"

    fleche_droite "CLIENT" "BROADCAST" \
        "DHCP DECLINE — L'IP $OFFRE_IP est déjà utilisée, je refuse !" "$RED"

    log_warn "Le serveur marque $OFFRE_IP comme conflictuelle"
    log_info "Le client relance un DHCP DISCOVER"
    echo ""
}

# ────────────────────────────────────────────────────────────
# Menu principal
# ────────────────────────────────────────────────────────────

menu() {
    clear
    banner "SIMULATION DHCP — Réseau & Système d'exploitation"

    echo -e "  ${BOLD}Scénarios disponibles :${NC}"
    echo ""
    echo -e "  ${BOLD}1)${NC} Processus DORA complet        (attribution d'IP)"
    echo -e "  ${BOLD}2)${NC} Renouvellement du bail         (T1, T2)"
    echo -e "  ${BOLD}3)${NC} DHCP RELEASE                  (libération volontaire)"
    echo -e "  ${BOLD}4)${NC} DHCP NAK                      (refus du serveur)"
    echo -e "  ${BOLD}5)${NC} DHCP DECLINE                  (refus du client)"
    echo -e "  ${BOLD}6)${NC} Tout afficher"
    echo -e "  ${BOLD}0)${NC} Quitter"
    echo ""
    echo -ne "  ${BOLD}Votre choix :${NC} "
    read -r choix

    case "$choix" in
        1) simulation_dora ;;
        2) simulation_renouvellement ;;
        3) simulation_release ;;
        4) simulation_nak ;;
        5) simulation_decline ;;
        6)
            simulation_dora
            sleep 1; simulation_renouvellement
            sleep 1; simulation_release
            sleep 1; simulation_nak
            sleep 1; simulation_decline
            ;;
        0) echo -e "\n${DIM}Au revoir !${NC}\n"; exit 0 ;;
        *) log_error "Choix invalide" ;;
    esac

    echo -ne "\n  ${DIM}Appuyez sur Entrée pour revenir au menu...${NC}"
    read -r
    menu
}

menu