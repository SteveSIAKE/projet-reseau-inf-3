#!/bin/bash
# ============================================================
#  dns_client.sh — Client DNS réel (dig + /dev/udp)
#  Effectue de vraies requêtes DNS et affiche les résultats
#  Projet Réseau & SE — Protocoles en Shell
# ============================================================

source "$(dirname "$0")/../utils/logger.sh"

DNS_SERVER="${DNS_SERVER:-8.8.8.8}"   # Serveur DNS par défaut (Google)
DNS_PORT=53

# ────────────────────────────────────────────────────────────
# Vérifier les dépendances
# ────────────────────────────────────────────────────────────

verifier_outils() {
    local outils=("dig" "nslookup")
    local manquants=()

    for outil in "${outils[@]}"; do
        if ! command -v "$outil" &>/dev/null; then
            manquants+=("$outil")
        fi
    done

    if [ ${#manquants[@]} -gt 0 ]; then
        log_warn "Outils manquants : ${manquants[*]}"
        log_info "Installation : sudo apt install -y dnsutils"
        exit 1
    fi

    log_success "Tous les outils sont disponibles (dig, nslookup)"
}

# ────────────────────────────────────────────────────────────
# Requête DNS avec dig — Type A (IPv4)
# ────────────────────────────────────────────────────────────

requete_A() {
    local domain="$1"
    banner "REQUÊTE DNS TYPE A — $domain"

    log_info "Serveur DNS utilisé : $DNS_SERVER (port $DNS_PORT / UDP)"
    log_send "Envoi requête A pour : $domain"
    echo ""

    local debut fin duree
    debut=$(date +%s%N)

    # Requête réelle avec dig
    local reponse
    reponse=$(dig @"$DNS_SERVER" "$domain" A +noall +answer +stats 2>/dev/null)

    fin=$(date +%s%N)
    duree=$(( (fin - debut) / 1000000 ))

    if [ -z "$reponse" ]; then
        log_error "Aucune réponse du serveur DNS"
        return 1
    fi

    # Affichage formaté
    echo -e "${WHITE}┌──────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│${BOLD}  RÉPONSE DNS — Type A (IPv4)                         ${WHITE}│${NC}"
    echo -e "${WHITE}├──────────────────────────────────────────────────────┤${NC}"

    while IFS=$'\t' read -r nom ttl classe type ip; do
        [ -z "$nom" ] && continue
        printf "${WHITE}│${NC}  ${CYAN}%-30s${NC} ${YELLOW}%-6s${NC} ${GREEN}%s${NC}\n" \
               "$nom" "TTL:$ttl" "$ip"
    done <<< "$reponse"

    echo -e "${WHITE}├──────────────────────────────────────────────────────┤${NC}"
    printf "${WHITE}│${NC}  %-52s ${WHITE}│${NC}\n" "Temps de réponse : ${duree}ms"
    echo -e "${WHITE}└──────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ────────────────────────────────────────────────────────────
# Requête DNS — Type AAAA (IPv6)
# ────────────────────────────────────────────────────────────

requete_AAAA() {
    local domain="$1"
    banner "REQUÊTE DNS TYPE AAAA — $domain (IPv6)"

    log_send "Envoi requête AAAA pour : $domain"
    echo ""

    local reponse
    reponse=$(dig @"$DNS_SERVER" "$domain" AAAA +short 2>/dev/null)

    if [ -z "$reponse" ]; then
        log_warn "Aucun enregistrement AAAA trouvé pour $domain"
    else
        log_recv "Adresses IPv6 reçues :"
        while IFS= read -r ligne; do
            echo -e "    ${GREEN}▶${NC} $ligne"
        done <<< "$reponse"
    fi
    echo ""
}

# ────────────────────────────────────────────────────────────
# Requête DNS — Type MX (Mail Exchange)
# ────────────────────────────────────────────────────────────

requete_MX() {
    local domain="$1"
    banner "REQUÊTE DNS TYPE MX — Serveurs mail de $domain"

    log_send "Envoi requête MX pour : $domain"
    echo ""

    local reponse
    reponse=$(dig @"$DNS_SERVER" "$domain" MX +noall +answer 2>/dev/null)

    if [ -z "$reponse" ]; then
        log_warn "Aucun enregistrement MX pour $domain"
        return
    fi

    echo -e "${WHITE}┌──────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│${BOLD}  SERVEURS DE MESSAGERIE (MX)                         ${WHITE}│${NC}"
    echo -e "${WHITE}├─────────────────┬──────────┬────────────────────────┤${NC}"
    echo -e "${WHITE}│${BOLD} Domaine          ${WHITE}│${BOLD} Priorité ${WHITE}│${BOLD} Serveur mail           ${WHITE}│${NC}"
    echo -e "${WHITE}├─────────────────┼──────────┼────────────────────────┤${NC}"

    echo "$reponse" | while read -r nom ttl classe type prio serveur; do
        [ -z "$type" ] && continue
        printf "${WHITE}│${NC} ${CYAN}%-16s${NC} ${WHITE}│${NC} ${YELLOW}%-9s${NC} ${WHITE}│${NC} ${GREEN}%-22s${NC} ${WHITE}│${NC}\n" \
               "$nom" "$prio" "$serveur"
    done

    echo -e "${WHITE}└─────────────────┴──────────┴────────────────────────┘${NC}"
    echo ""
    echo -e "${DIM}  Note : La priorité la plus basse est préférée (ex: 10 < 20)${NC}"
    echo ""
}

# ────────────────────────────────────────────────────────────
# Requête DNS — Type NS (Name Servers)
# ────────────────────────────────────────────────────────────

requete_NS() {
    local domain="$1"
    banner "REQUÊTE DNS TYPE NS — Serveurs de noms de $domain"

    log_send "Envoi requête NS pour : $domain"
    echo ""

    local reponse
    reponse=$(dig @"$DNS_SERVER" "$domain" NS +short 2>/dev/null)

    if [ -z "$reponse" ]; then
        log_warn "Aucun enregistrement NS pour $domain"
        return
    fi

    log_recv "Serveurs de noms autoritaires :"
    echo ""
    while IFS= read -r ns; do
        [ -z "$ns" ] && continue
        echo -e "  ${GREEN}▶${NC} ${CYAN}$ns${NC}"

        # Résolution IP du NS
        local ns_ip
        ns_ip=$(dig @"$DNS_SERVER" "$ns" A +short 2>/dev/null | head -1)
        [ -n "$ns_ip" ] && echo -e "    ${DIM}→ IP : $ns_ip${NC}"
    done <<< "$reponse"
    echo ""
}

# ────────────────────────────────────────────────────────────
# Requête DNS — CNAME (Alias)
# ────────────────────────────────────────────────────────────

requete_CNAME() {
    local domain="$1"
    banner "REQUÊTE DNS TYPE CNAME — Alias de $domain"

    log_send "Envoi requête CNAME pour : $domain"
    echo ""

    local reponse
    reponse=$(dig @"$DNS_SERVER" "$domain" CNAME +noall +answer 2>/dev/null)

    if [ -z "$reponse" ]; then
        log_warn "Aucun CNAME pour $domain (c'est peut-être un enregistrement A direct)"
    else
        log_recv "Chaîne d'alias :"
        echo ""
        echo "$reponse" | while read -r nom ttl c type valeur; do
            [ -z "$type" ] && continue
            echo -e "  ${CYAN}$nom${NC} ${YELLOW}→ CNAME →${NC} ${GREEN}$valeur${NC}"
        done
    fi
    echo ""
}

# ────────────────────────────────────────────────────────────
# Résolution inverse (PTR)
# ────────────────────────────────────────────────────────────

requete_PTR() {
    local ip="$1"
    banner "RÉSOLUTION INVERSE (PTR) — $ip"

    log_info "Résolution inverse : IP → Nom de domaine"
    log_send "Requête PTR pour : $ip"
    echo ""

    local reponse
    reponse=$(dig @"$DNS_SERVER" -x "$ip" +short 2>/dev/null)

    if [ -z "$reponse" ]; then
        log_warn "Aucun enregistrement PTR pour $ip"
    else
        log_recv "Nom de domaine associé :"
        echo ""
        echo -e "  ${CYAN}$ip${NC}  ${YELLOW}→ PTR →${NC}  ${GREEN}$reponse${NC}"
    fi
    echo ""
}

# ────────────────────────────────────────────────────────────
# Requête DNS complète (toutes les infos)
# ────────────────────────────────────────────────────────────

requete_complete() {
    local domain="$1"
    banner "ANALYSE DNS COMPLÈTE — $domain"

    log_info "Utilisation de : dig @${DNS_SERVER} ${domain} ANY"
    echo ""

    local reponse
    reponse=$(dig @"$DNS_SERVER" "$domain" ANY +noall +answer 2>/dev/null)

    if [ -z "$reponse" ]; then
        # Fallback : plusieurs requêtes séparées
        log_warn "ANY non supporté, requêtes séparées en cours..."
        requete_A "$domain"
        requete_MX "$domain"
        requete_NS "$domain"
    else
        echo -e "${BOLD}Résultats bruts (dig) :${NC}"
        separator
        echo "$reponse"
        separator
    fi
}

# ────────────────────────────────────────────────────────────
# Trace du chemin DNS (simulation du parcours réel)
# ────────────────────────────────────────────────────────────

trace_dns() {
    local domain="$1"
    banner "TRACE DNS — Parcours de résolution pour $domain"

    log_info "On va suivre le chemin complet de résolution DNS"
    echo ""

    # Serveurs racines
    log_step 1 "Interrogation d'un serveur RACINE"
    local racine_ns
    racine_ns=$(dig @198.41.0.4 "$domain" NS +noall +authority 2>/dev/null | head -3)
    if [ -n "$racine_ns" ]; then
        log_success "Serveur racine a répondu :"
        echo "$racine_ns" | while read -r ligne; do
            [ -n "$ligne" ] && echo -e "  ${DIM}$ligne${NC}"
        done
    fi
    echo ""

    # TLD
    log_step 2 "Extraction du serveur TLD"
    local tld
    tld=$(echo "$domain" | rev | cut -d. -f1 | rev)
    local tld_server
    tld_server=$(dig @198.41.0.4 "$tld" NS +short 2>/dev/null | head -1)
    log_info "TLD : .$tld — Serveur TLD : $tld_server"
    echo ""

    # Serveur autoritaire
    log_step 3 "Identification du serveur autoritaire"
    local auth_server
    auth_server=$(dig @"$DNS_SERVER" "$domain" NS +short 2>/dev/null | head -1)
    log_info "Serveur autoritaire : $auth_server"
    echo ""

    # Résolution finale
    log_step 4 "Résolution finale de l'adresse IP"
    local ip_finale
    ip_finale=$(dig @"$DNS_SERVER" "$domain" A +short 2>/dev/null | head -1)
    if [ -n "$ip_finale" ]; then
        log_success "$domain → $ip_finale"
    else
        log_error "Impossible de résoudre $domain"
    fi
    echo ""
}

# ────────────────────────────────────────────────────────────
# Menu principal
# ────────────────────────────────────────────────────────────

menu() {
    banner "CLIENT DNS RÉEL — Réseau & Système d'exploitation"
    echo -e "  ${BOLD}Serveur DNS :${NC} ${CYAN}$DNS_SERVER${NC} (port 53/UDP)"
    echo ""
    echo -e "  ${BOLD}Domaine à tester :${NC}"
    echo -ne "  → "
    read -r DOMAIN
    [ -z "$DOMAIN" ] && DOMAIN="google.com"
    echo ""
    echo -e "  ${BOLD}1)${NC} Requête A     — Adresse IPv4"
    echo -e "  ${BOLD}2)${NC} Requête AAAA  — Adresse IPv6"
    echo -e "  ${BOLD}3)${NC} Requête MX    — Serveurs mail"
    echo -e "  ${BOLD}4)${NC} Requête NS    — Serveurs de noms"
    echo -e "  ${BOLD}5)${NC} Requête CNAME — Alias"
    echo -e "  ${BOLD}6)${NC} Résolution inverse (PTR) — entrez une IP"
    echo -e "  ${BOLD}7)${NC} Analyse complète"
    echo -e "  ${BOLD}8)${NC} Trace DNS (parcours complet)"
    echo -e "  ${BOLD}0)${NC} Quitter"
    echo ""
    echo -ne "  ${BOLD}Choix :${NC} "
    read -r choix

    case "$choix" in
        1) requete_A "$DOMAIN" ;;
        2) requete_AAAA "$DOMAIN" ;;
        3) requete_MX "$DOMAIN" ;;
        4) requete_NS "$DOMAIN" ;;
        5) requete_CNAME "$DOMAIN" ;;
        6)
            echo -ne "  Entrez l'adresse IP : "
            read -r ip
            requete_PTR "$ip"
            ;;
        7) requete_complete "$DOMAIN" ;;
        8) trace_dns "$DOMAIN" ;;
        0) echo -e "\n${DIM}Au revoir !${NC}\n"; exit 0 ;;
        *) log_error "Choix invalide" ;;
    esac

    echo -ne "  ${DIM}Appuyez sur Entrée pour continuer...${NC}"
    read -r
    menu
}

# Vérification des outils puis lancement
verifier_outils
menu
