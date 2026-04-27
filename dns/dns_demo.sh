#!/bin/bash
# ============================================================
#  dns_demo.sh — Démonstration complète DNS tout-en-un
#  Lance une présentation guidée du protocole DNS
#  Projet Réseau & SE — Protocoles en Shell
# ============================================================

source "$(dirname "$0")/../utils/logger.sh"

DOMAIN="${1:-google.com}"

intro() {
    clear
    echo -e "${BOLD}${BLUE}"
    cat << 'EOF'
  ██████  ███    ██ ███████
  ██   ██ ████   ██ ██
  ██   ██ ██ ██  ██ ███████
  ██   ██ ██  ██ ██      ██
  ██████  ██   ████ ███████

  Domain Name System — Démonstration Shell
EOF
    echo -e "${NC}"
    echo -e "${DIM}  Projet Réseau & Système d'exploitation${NC}"
    echo -e "${DIM}  Implémentation en Shell Script — Linux${NC}"
    echo ""
    separator
    echo ""
    echo -e "  Ce script démontre le fonctionnement du protocole DNS :"
    echo ""
    echo -e "  ${GREEN}✓${NC}  Rôle et architecture du DNS"
    echo -e "  ${GREEN}✓${NC}  Résolution récursive vs itérative (simulation)"
    echo -e "  ${GREEN}✓${NC}  Types d'enregistrements (A, AAAA, MX, NS, CNAME, PTR)"
    echo -e "  ${GREEN}✓${NC}  Requêtes DNS réelles avec ${CYAN}dig${NC}"
    echo -e "  ${GREEN}✓${NC}  Cache DNS et TTL"
    echo -e "  ${GREEN}✓${NC}  Serveur DNS simplifié"
    echo ""
    separator
    echo ""
    echo -ne "  ${DIM}Appuyez sur Entrée pour commencer...${NC}"
    read -r
}

partie_1_architecture() {
    clear
    banner "PARTIE 1 — Architecture du DNS"

    echo -e "${BOLD}  Qu'est-ce que DNS ?${NC}"
    echo ""
    echo -e "  DNS = Domain Name System"
    echo -e "  C'est l'annuaire d'Internet : il traduit les noms"
    echo -e "  de domaines en adresses IP."
    echo ""
    echo -e "  ${CYAN}www.google.com${NC}  →  ${GREEN}142.250.185.68${NC}"
    echo ""
    pause "Chargement de l'architecture"
    echo ""

    echo -e "${BOLD}  Hiérarchie DNS :${NC}"
    echo ""
    echo -e "          ${WHITE}. (Racine)${NC}"
    echo -e "         /    |    \\"
    echo -e "       ${CYAN}.com${NC}  ${CYAN}.org${NC}  ${CYAN}.cm${NC}  ← TLD (Top Level Domain)"
    echo -e "       /           \\"
    echo -e "  ${GREEN}google.com${NC}     ${GREEN}gouvernement.cm${NC}  ← Domaines de 2ème niveau"
    echo -e "     /                   \\"
    echo -e "  ${MAGENTA}www.google.com${NC}    ${MAGENTA}www.gouv.cm${NC}  ← Sous-domaines"
    echo ""
    separator
    echo ""
    echo -e "${BOLD}  Acteurs de la résolution DNS :${NC}"
    echo ""
    printf "  ${YELLOW}%-22s${NC} %s\n" "Client DNS"       "→ Le navigateur/app qui pose la question"
    printf "  ${YELLOW}%-22s${NC} %s\n" "Résolveur récursif" "→ Serveur du FAI ou 8.8.8.8 (Google)"
    printf "  ${YELLOW}%-22s${NC} %s\n" "Serveurs racines"  "→ 13 serveurs mondiaux (a.root-servers.net...)"
    printf "  ${YELLOW}%-22s${NC} %s\n" "Serveurs TLD"      "→ Gèrent .com, .org, .cm..."
    printf "  ${YELLOW}%-22s${NC} %s\n" "Serveurs autoritaires" "→ Réponse finale pour un domaine"
    echo ""
}

partie_2_simulation() {
    clear
    banner "PARTIE 2 — Simulation de la résolution"
    echo -e "  ${DIM}Lancement de dns_sim.sh en mode automatique...${NC}"
    echo ""
    sleep 1
    bash "$(dirname "$0")/dns_sim.sh" "$DOMAIN" <<< "5"  # Option "tout afficher"
}

partie_3_requetes_reelles() {
    clear
    banner "PARTIE 3 — Requêtes DNS réelles"

    if ! command -v dig &>/dev/null; then
        log_warn "dig non installé. Installez : sudo apt install dnsutils"
        echo ""
        log_info "Simulation d'une sortie dig :"
        echo ""
        echo -e "${DIM}; <<>> DiG 9.18 <<>> @8.8.8.8 $DOMAIN A"
        echo -e ";; QUESTION SECTION:"
        echo -e ";$DOMAIN.        IN  A"
        echo -e ""
        echo -e ";; ANSWER SECTION:"
        echo -e "$DOMAIN.   300  IN  A  142.250.185.68"
        echo -e "$DOMAIN.   300  IN  A  142.250.185.165"
        echo -e ""
        echo -e ";; Query time: 12 msec"
        echo -e ";; SERVER: 8.8.8.8#53(8.8.8.8)"
        echo -e ";; MSG SIZE  rcvd: 83${NC}"
    else
        log_info "Requêtes réelles via dig @8.8.8.8"
        echo ""

        log_step "A" "Enregistrement A (IPv4) pour $DOMAIN"
        dig @8.8.8.8 "$DOMAIN" A +noall +answer +stats 2>/dev/null | head -10
        echo ""
        sleep 0.5

        log_step "MX" "Serveurs mail de $DOMAIN"
        dig @8.8.8.8 "$DOMAIN" MX +short 2>/dev/null | head -5
        echo ""
        sleep 0.5

        log_step "NS" "Serveurs de noms de $DOMAIN"
        dig @8.8.8.8 "$DOMAIN" NS +short 2>/dev/null | head -5
        echo ""
    fi
}

partie_4_udp() {
    clear
    banner "PARTIE 4 — DNS et le protocole UDP"

    echo -e "${BOLD}  Pourquoi DNS utilise UDP (port 53) ?${NC}"
    echo ""
    echo -e "  ${GREEN}✓${NC}  UDP est plus rapide que TCP (pas de connexion)"
    echo -e "  ${GREEN}✓${NC}  Les paquets DNS sont petits (< 512 octets en général)"
    echo -e "  ${GREEN}✓${NC}  Le cache compense l'absence de fiabilité"
    echo -e "  ${YELLOW}⚠${NC}  TCP utilisé si réponse > 512 octets (DNSSEC, zone transfer)"
    echo ""
    separator
    echo ""
    echo -e "${BOLD}  Structure d'un paquet DNS (en-tête) :${NC}"
    echo ""
    echo -e "${WHITE}  ┌──────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}  │${NC} ${YELLOW}ID (16 bits)${NC}        ${CYAN}Flags (16 bits)${NC}           ${WHITE}│${NC}"
    echo -e "${WHITE}  ├──────────────────────────────────────────────────┤${NC}"
    echo -e "${WHITE}  │${NC} QDCOUNT (nb questions)  ANCOUNT (nb réponses) ${WHITE}│${NC}"
    echo -e "${WHITE}  ├──────────────────────────────────────────────────┤${NC}"
    echo -e "${WHITE}  │${NC} NSCOUNT (nb NS)         ARCOUNT (nb ajouts)   ${WHITE}│${NC}"
    echo -e "${WHITE}  ├──────────────────────────────────────────────────┤${NC}"
    echo -e "${WHITE}  │${NC} QUESTION : nom de domaine + type + classe     ${WHITE}│${NC}"
    echo -e "${WHITE}  ├──────────────────────────────────────────────────┤${NC}"
    echo -e "${WHITE}  │${NC} RÉPONSE  : nom + type + TTL + données         ${WHITE}│${NC}"
    echo -e "${WHITE}  └──────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${DIM}  Total en-tête : 12 octets fixes${NC}"
    echo ""
    separator
    echo ""

    log_info "Explication des flags DNS :"
    echo ""
    printf "  ${YELLOW}%-12s${NC} %s\n" "QR (1 bit)"    "0=Question, 1=Réponse"
    printf "  ${YELLOW}%-12s${NC} %s\n" "OPCODE (4b)"   "0=Standard, 1=Inverse, 2=Status"
    printf "  ${YELLOW}%-12s${NC} %s\n" "AA (1 bit)"    "Réponse autoritaire"
    printf "  ${YELLOW}%-12s${NC} %s\n" "TC (1 bit)"    "Message tronqué (→ passer à TCP)"
    printf "  ${YELLOW}%-12s${NC} %s\n" "RD (1 bit)"    "Récursion désirée"
    printf "  ${YELLOW}%-12s${NC} %s\n" "RA (1 bit)"    "Récursion disponible"
    printf "  ${YELLOW}%-12s${NC} %s\n" "RCODE (4b)"    "0=OK, 3=NXDOMAIN, 2=SERVFAIL..."
    echo ""
}

resume_final() {
    clear
    banner "RÉSUMÉ — Protocole DNS"

    echo -e "${BOLD}  Ce que vous avez vu :${NC}"
    echo ""
    echo -e "  ${GREEN}✓${NC}  DNS traduit noms → adresses IP (et inversement)"
    echo -e "  ${GREEN}✓${NC}  Résolution récursive : le résolveur fait tout"
    echo -e "  ${GREEN}✓${NC}  Résolution itérative : le client fait tout lui-même"
    echo -e "  ${GREEN}✓${NC}  Hiérarchie : Racine → TLD → Autoritaire → Réponse"
    echo -e "  ${GREEN}✓${NC}  TTL : durée de validité d'une entrée en cache"
    echo -e "  ${GREEN}✓${NC}  UDP port 53 (TCP si > 512 octets)"
    echo ""
    separator
    echo ""
    echo -e "${BOLD}  Scripts disponibles :${NC}"
    echo ""
    printf "  ${CYAN}%-25s${NC} %s\n" "dns_sim.sh"    "Simulation visuelle interactive"
    printf "  ${CYAN}%-25s${NC} %s\n" "dns_client.sh" "Requêtes DNS réelles (dig)"
    printf "  ${CYAN}%-25s${NC} %s\n" "dns_server.sh" "Serveur DNS simplifié (nc)"
    printf "  ${CYAN}%-25s${NC} %s\n" "dns_demo.sh"   "Cette démonstration complète"
    echo ""
    separator
    echo ""
    echo -e "  ${BOLD}Commandes utiles :${NC}"
    echo ""
    echo -e "  ${DIM}# Requête DNS simple${NC}"
    echo -e "  ${WHITE}dig google.com${NC}"
    echo ""
    echo -e "  ${DIM}# Requête sur un serveur spécifique${NC}"
    echo -e "  ${WHITE}dig @8.8.8.8 google.com MX${NC}"
    echo ""
    echo -e "  ${DIM}# Résolution inverse${NC}"
    echo -e "  ${WHITE}dig -x 8.8.8.8${NC}"
    echo ""
    echo -e "  ${DIM}# Trace complète de résolution${NC}"
    echo -e "  ${WHITE}dig +trace google.com${NC}"
    echo ""
}

# ────────────────────────────────────────────────────────────
# Lancement de la démo
# ────────────────────────────────────────────────────────────

intro
partie_1_architecture
echo -ne "  ${DIM}[Entrée pour continuer]${NC}"; read -r

partie_2_simulation
echo -ne "  ${DIM}[Entrée pour continuer]${NC}"; read -r

partie_3_requetes_reelles
echo -ne "  ${DIM}[Entrée pour continuer]${NC}"; read -r

partie_4_udp
echo -ne "  ${DIM}[Entrée pour continuer]${NC}"; read -r

resume_final
echo -e "\n  ${GREEN}Démonstration terminée ! Bonne soutenance 🎓${NC}\n"
