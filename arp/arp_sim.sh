#!/bin/bash
# ============================================================
#  arp_sim.sh — Simulation visuelle du protocole ARP
#  Illustre : ARP Request/Reply, cache, gratuitous ARP, spoofing
#  Projet Réseau & SE — Protocoles en Shell
# ============================================================

source "$(dirname "$0")/../utils/logger.sh"

CLIENT_IP="192.168.1.10"
CLIENT_MAC="AA:BB:CC:DD:EE:10"
CLIENT_HOST="PC-Etudiant"

CIBLE_IP="192.168.1.1"
CIBLE_MAC="00:11:22:33:44:55"
CIBLE_HOST="Routeur"

ATTAQUANT_IP="192.168.1.66"
ATTAQUANT_MAC="66:66:66:66:66:66"

afficher_paquet_arp() {
    local titre="$1" src_ip="$2" src_mac="$3" dst_ip="$4" dst_mac="$5" opcode="$6"
    echo ""
    echo -e "${WHITE}╔══════════════════════════════════════════════════════╗${NC}"
    printf  "${WHITE}║${BOLD}  %-52s${WHITE}║${NC}\n" "PAQUET ARP — $titre"
    echo -e "${WHITE}╠══════════════════════════════════════════════════════╣${NC}"
    printf  "${WHITE}║${NC}  %-18s : %-30s ${WHITE}║${NC}\n" "Opcode" "$opcode"
    printf  "${WHITE}║${NC}  %-18s : %-30s ${WHITE}║${NC}\n" "Sender IP" "$src_ip"
    printf  "${WHITE}║${NC}  %-18s : %-30s ${WHITE}║${NC}\n" "Sender MAC" "$src_mac"
    printf  "${WHITE}║${NC}  %-18s : %-30s ${WHITE}║${NC}\n" "Target IP" "$dst_ip"
    printf  "${WHITE}║${NC}  %-18s : %-30s ${WHITE}║${NC}\n" "Target MAC" "$dst_mac"
    echo -e "${WHITE}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    sleep 0.7
}

fleche() {
    local src="$1" dst="$2" msg="$3"
    printf "  ${CYAN}%-14s${NC} ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━→${NC} ${GREEN}%s${NC}\n" "$src" "$dst"
    echo -e "                 ${DIM}$msg${NC}"
    echo ""
    sleep 0.7
}

fleche_retour() {
    local src="$1" dst="$2" msg="$3"
    printf "  ${GREEN}%-14s${NC} ${YELLOW}←━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC} ${CYAN}%s${NC}\n" "$src" "$dst"
    echo -e "                 ${DIM}$msg${NC}"
    echo ""
    sleep 0.7
}

simulation_resolution_arp() {
    clear
    banner "ARP — RESOLUTION D'ADRESSE (REQUEST / REPLY)"
    echo -e "  ${BOLD}Objectif :${NC} retrouver la MAC de ${CYAN}$CIBLE_IP${NC}"
    echo ""
    separator
    sleep 1

    log_step 1 "Le client doit envoyer un paquet IP à la passerelle."
    log_info "$CLIENT_HOST connaît l'IP $CIBLE_IP, mais pas la MAC associée."
    echo ""

    afficher_paquet_arp "ARP REQUEST (Broadcast)" \
        "$CLIENT_IP" "$CLIENT_MAC" "$CIBLE_IP" "00:00:00:00:00:00" \
        "1 (request)"
    fleche "$CLIENT_HOST" "BROADCAST FF:FF:FF:FF:FF:FF" \
        "Qui a $CIBLE_IP ? Répondez à $CLIENT_IP"

    log_step 2 "Le routeur répond en unicast."
    afficher_paquet_arp "ARP REPLY (Unicast)" \
        "$CIBLE_IP" "$CIBLE_MAC" "$CLIENT_IP" "$CLIENT_MAC" \
        "2 (reply)"
    fleche_retour "$CLIENT_HOST" "$CIBLE_HOST" \
        "$CIBLE_IP est à l'adresse MAC $CIBLE_MAC"

    log_step 3 "Mise en cache ARP côté client."
    echo -e "${WHITE}┌────────────────────────────┬──────────────────────┬─────────┐${NC}"
    echo -e "${WHITE}│${BOLD} IP                         ${WHITE}│${BOLD} MAC                  ${WHITE}│${BOLD} Etat    ${WHITE}│${NC}"
    echo -e "${WHITE}├────────────────────────────┼──────────────────────┼─────────┤${NC}"
    printf  "${WHITE}│${NC} ${CYAN}%-26s${NC} ${WHITE}│${NC} ${GREEN}%-20s${NC} ${WHITE}│${NC} %s ${WHITE}│${NC}\n" \
            "$CIBLE_IP" "$CIBLE_MAC" "REACH"
    echo -e "${WHITE}└────────────────────────────┴──────────────────────┴─────────┘${NC}"
    echo ""
    log_success "Le client peut maintenant encapsuler son paquet IP dans une trame Ethernet."
    echo ""
}

simulation_cache_hit() {
    clear
    banner "ARP — CACHE HIT (PAS DE NOUVELLE REQUETE)"
    echo -e "  Une entrée ARP valide existe déjà pour ${CYAN}$CIBLE_IP${NC}."
    echo ""
    separator
    sleep 1

    log_step 1 "Le client vérifie sa table ARP locale."
    echo -e "  ${GREEN}[CACHE HIT]${NC} $CIBLE_IP -> $CIBLE_MAC"
    echo ""

    log_step 2 "Le client envoie directement la trame Ethernet."
    fleche "$CLIENT_HOST" "$CIBLE_HOST" \
        "Trame unicast immédiate (aucun ARP Request)"

    log_success "Latence réduite grâce au cache ARP."
    echo -e "  ${DIM}Les entrées ARP expirent après un délai d'inactivité.${NC}"
    echo ""
}

simulation_gratuitous_arp() {
    clear
    banner "ARP GRATUITOUS — ANNONCE D'UNE IP"
    echo -e "  Le poste ${CYAN}$CLIENT_HOST${NC} annonce sa propre association IP/MAC."
    echo ""
    separator
    sleep 1

    log_step 1 "Emission d'un ARP gratuitous en broadcast."
    afficher_paquet_arp "GRATUITOUS ARP" \
        "$CLIENT_IP" "$CLIENT_MAC" "$CLIENT_IP" "00:00:00:00:00:00" \
        "1 (request gratuitous)"
    fleche "$CLIENT_HOST" "BROADCAST" \
        "Annonce: $CLIENT_IP est porté par $CLIENT_MAC"

    log_info "Utilisations courantes :"
    echo -e "  ${GREEN}•${NC} Détecter conflit d'IP au démarrage"
    echo -e "  ${GREEN}•${NC} Mettre à jour les caches ARP voisins"
    echo -e "  ${GREEN}•${NC} Bascules HA (VRRP, failover)"
    echo ""
}

simulation_spoofing() {
    clear
    banner "ARP SPOOFING — ATTAQUE MAN-IN-THE-MIDDLE"
    echo -e "  ${RED}Scénario pédagogique${NC} : empoisonnement de cache ARP."
    echo ""
    separator
    sleep 1

    log_step 1 "L'attaquant envoie de faux ARP Reply."
    afficher_paquet_arp "FAUX ARP REPLY (vers client)" \
        "$CIBLE_IP" "$ATTAQUANT_MAC" "$CLIENT_IP" "$CLIENT_MAC" \
        "2 (reply forgé)"
    fleche_retour "$CLIENT_HOST" "ATTAQUANT" \
        "Le client croit que $CIBLE_IP -> $ATTAQUANT_MAC"

    log_step 2 "La table ARP du client est corrompue."
    echo -e "${WHITE}┌────────────────────────────┬──────────────────────┬──────────────┐${NC}"
    echo -e "${WHITE}│${BOLD} IP                         ${WHITE}│${BOLD} MAC                  ${WHITE}│${BOLD} Commentaire   ${WHITE}│${NC}"
    echo -e "${WHITE}├────────────────────────────┼──────────────────────┼──────────────┤${NC}"
    printf  "${WHITE}│${NC} ${CYAN}%-26s${NC} ${WHITE}│${NC} ${RED}%-20s${NC} ${WHITE}│${NC} %-12s ${WHITE}│${NC}\n" \
            "$CIBLE_IP" "$ATTAQUANT_MAC" "empoisonne"
    echo -e "${WHITE}└────────────────────────────┴──────────────────────┴──────────────┘${NC}"
    echo ""

    log_warn "Conséquence : interception ou coupure du trafic."
    log_info "Contre-mesures : ARP statique, DHCP snooping + DAI, segmentation VLAN."
    echo ""
}

menu() {
    while true; do
        clear
        banner "SIMULATION ARP — Réseau & Système d'exploitation"
        echo -e "  ${BOLD}Scénarios disponibles :${NC}"
        echo ""
        echo -e "  ${BOLD}1)${NC} ARP Request / ARP Reply (résolution)"
        echo -e "  ${BOLD}2)${NC} Cache hit ARP"
        echo -e "  ${BOLD}3)${NC} Gratuitous ARP"
        echo -e "  ${BOLD}4)${NC} ARP spoofing (attaque)"
        echo -e "  ${BOLD}5)${NC} Tout afficher"
        echo -e "  ${BOLD}0)${NC} Quitter"
        echo ""
        echo -ne "  ${BOLD}Votre choix :${NC} "
        read -r choix

        case "$choix" in
            1) simulation_resolution_arp ;;
            2) simulation_cache_hit ;;
            3) simulation_gratuitous_arp ;;
            4) simulation_spoofing ;;
            5)
                simulation_resolution_arp
                sleep 1
                simulation_cache_hit
                sleep 1
                simulation_gratuitous_arp
                sleep 1
                simulation_spoofing
                ;;
            0) echo -e "\n${DIM}Au revoir !${NC}\n"; exit 0 ;;
            *) log_error "Choix invalide" ;;
        esac

        echo -ne "\n  ${DIM}Appuyez sur Entrée pour revenir au menu...${NC}"
        read -r
    done
}

menu
