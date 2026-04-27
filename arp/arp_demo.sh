#!/bin/bash
# ============================================================
#  arp_demo.sh — Démonstration complète ARP tout-en-un
#  Lance une présentation guidée du protocole ARP
#  Projet Réseau & SE — Protocoles en Shell
# ============================================================

source "$(dirname "$0")/../utils/logger.sh"

BASE_DIR="$(dirname "$0")"
ARP_SIM="$BASE_DIR/arp_sim.sh"
ARP_CLIENT="$BASE_DIR/arp_client.sh"

intro() {
    clear
    echo -e "${BOLD}${BLUE}"
    cat << 'EOF'
    █████  ██████  ██████
   ██   ██ ██   ██ ██   ██
   ███████ ██████  ██████
   ██   ██ ██   ██ ██
   ██   ██ ██   ██ ██

  Address Resolution Protocol — Démonstration Shell
EOF
    echo -e "${NC}"
    echo -e "${DIM}  Projet Réseau & Système d'exploitation${NC}"
    echo -e "${DIM}  Implémentation en Shell Script — Linux${NC}"
    echo ""
    separator
    echo ""
    echo -e "  Ce script démontre le fonctionnement du protocole ARP :"
    echo ""
    echo -e "  ${GREEN}✓${NC}  Rôle de ARP dans un LAN IPv4"
    echo -e "  ${GREEN}✓${NC}  Trame ARP Request / ARP Reply"
    echo -e "  ${GREEN}✓${NC}  Cache ARP et expiration des entrées"
    echo -e "  ${GREEN}✓${NC}  Gratuitous ARP et cas d'usage"
    echo -e "  ${GREEN}✓${NC}  Risque ARP spoofing (MITM)"
    echo -e "  ${GREEN}✓${NC}  Commandes réelles: ip neigh / arp / ping"
    echo ""
    separator
    echo ""
    echo -ne "  ${DIM}Appuyez sur Entrée pour commencer...${NC}"
    read -r
}

partie_1_concepts() {
    clear
    banner "PARTIE 1 — Concept ARP"

    echo -e "${BOLD}  Pourquoi ARP existe ?${NC}"
    echo ""
    echo -e "  Sur Ethernet, l'envoi local se fait avec des ${CYAN}adresses MAC${NC}."
    echo -e "  Les applications manipulent des ${CYAN}adresses IP${NC}."
    echo -e "  ARP fait la traduction : ${GREEN}IP -> MAC${NC} dans le même réseau local."
    echo ""
    separator
    echo ""
    echo -e "${BOLD}  Exemple :${NC}"
    echo -e "  ${CYAN}192.168.1.1${NC}  ->  ${GREEN}00:11:22:33:44:55${NC}"
    echo ""
    echo -e "${BOLD}  Principe de base :${NC}"
    echo ""
    echo -e "  ${YELLOW}1)${NC} Broadcast ARP Request  : \"Qui a 192.168.1.1 ?\""
    echo -e "  ${YELLOW}2)${NC} Unicast ARP Reply      : \"192.168.1.1 est à 00:11:22:33:44:55\""
    echo -e "  ${YELLOW}3)${NC} Mise en cache locale ARP"
    echo ""
}

partie_2_trame() {
    clear
    banner "PARTIE 2 — Structure d'un paquet ARP"
    echo -e "${WHITE}  ┌──────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}  │${NC} HTYPE (Ethernet=1) | PTYPE (IPv4=0x0800)      ${WHITE}│${NC}"
    echo -e "${WHITE}  ├──────────────────────────────────────────────────┤${NC}"
    echo -e "${WHITE}  │${NC} HLEN (6)            | PLEN (4)               ${WHITE}│${NC}"
    echo -e "${WHITE}  ├──────────────────────────────────────────────────┤${NC}"
    echo -e "${WHITE}  │${NC} OPER (1=request, 2=reply)                    ${WHITE}│${NC}"
    echo -e "${WHITE}  ├──────────────────────────────────────────────────┤${NC}"
    echo -e "${WHITE}  │${NC} Sender MAC | Sender IP                       ${WHITE}│${NC}"
    echo -e "${WHITE}  ├──────────────────────────────────────────────────┤${NC}"
    echo -e "${WHITE}  │${NC} Target MAC | Target IP                       ${WHITE}│${NC}"
    echo -e "${WHITE}  └──────────────────────────────────────────────────┘${NC}"
    echo ""
    log_info "ARP est encapsulé directement dans Ethernet (pas UDP/TCP)."
    echo ""
}

partie_3_simulation() {
    clear
    banner "PARTIE 3 — Simulation visuelle ARP"
    echo -e "  ${DIM}Lancement de arp_sim.sh en mode automatique (Tout afficher)...${NC}"
    echo ""
    sleep 1
    bash "$ARP_SIM" <<< $'5\n\n0\n'
}

partie_4_commandes_reelles() {
    clear
    banner "PARTIE 4 — ARP sur la machine locale"

    if ! command -v ip >/dev/null 2>&1; then
        log_warn "La commande 'ip' est absente."
        log_info "Installe : sudo apt install -y iproute2 iputils-ping net-tools"
        echo ""
    else
        log_step 1 "Table ARP actuelle (ip neigh)"
        ip neigh show 2>/dev/null || true
        echo ""

        log_step 2 "Entrée ARP de la gateway par défaut (si trouvée)"
        local gw
        gw=$(ip route 2>/dev/null | awk '/default/ {print $3; exit}')
        if [ -n "$gw" ]; then
            echo -e "  Gateway détectée : ${CYAN}$gw${NC}"
            ping -c 1 -W 1 "$gw" >/dev/null 2>&1 || true
            ip neigh show "$gw" 2>/dev/null || true
        else
            log_warn "Aucune gateway par défaut détectée."
        fi
        echo ""
    fi

    log_info "Tu peux aussi ouvrir le menu interactif du client ARP."
    echo -ne "  Lancer maintenant arp_client.sh ? (oui/non) : "
    local rep
    read -r rep
    if [ "$rep" = "oui" ]; then
        bash "$ARP_CLIENT"
    fi
}

resume_final() {
    clear
    banner "RÉSUMÉ — Protocole ARP"
    echo -e "  ${GREEN}✓${NC} ARP traduit ${CYAN}IP${NC} en ${CYAN}MAC${NC} sur un LAN IPv4"
    echo -e "  ${GREEN}✓${NC} ARP Request = broadcast ; ARP Reply = unicast"
    echo -e "  ${GREEN}✓${NC} Les entrées ARP sont mises en cache (accélération)"
    echo -e "  ${GREEN}✓${NC} Gratuitous ARP sert à annoncer/mettre à jour une IP"
    echo -e "  ${GREEN}✓${NC} ARP spoofing peut détourner le trafic (MITM)"
    echo ""
    separator
    echo ""
    printf "  ${CYAN}%-25s${NC} %s\n" "arp_sim.sh" "Simulation visuelle interactive"
    printf "  ${CYAN}%-25s${NC} %s\n" "arp_client.sh" "Consultation/manipulation ARP réelle"
    printf "  ${CYAN}%-25s${NC} %s\n" "arp_demo.sh" "Démonstration complète guidée"
    echo ""
}

main() {
    chmod +x "$ARP_SIM" "$ARP_CLIENT" "$0" >/dev/null 2>&1 || true
    intro
    partie_1_concepts
    echo -ne "  ${DIM}[Entrée pour continuer]${NC}"
    read -r

    partie_2_trame
    echo -ne "  ${DIM}[Entrée pour continuer]${NC}"
    read -r

    partie_3_simulation
    echo -ne "  ${DIM}[Entrée pour continuer]${NC}"
    read -r

    partie_4_commandes_reelles
    echo -ne "  ${DIM}[Entrée pour continuer]${NC}"
    read -r

    resume_final
    echo -e "\n  ${GREEN}Démonstration ARP terminée. Bonne soutenance.${NC}\n"
}

main
