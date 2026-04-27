#!/bin/bash
# ============================================================
#  dns_sim.sh — Simulation visuelle de la résolution DNS
#  Illustre : résolution récursive, itérative, cache DNS
#  Projet Réseau & SE — Protocoles en Shell
# ============================================================

source "$(dirname "$0")/../utils/logger.sh"

DOMAIN="${1:-www.google.com}"
CACHE_FILE="/tmp/dns_cache_sim.txt"

# ────────────────────────────────────────────────────────────
# Fonctions d'affichage
# ────────────────────────────────────────────────────────────

afficher_paquet_dns() {
    local src="$1" dst="$2" type="$3" contenu="$4"
    echo ""
    echo -e "${WHITE}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│${BOLD}  PAQUET DNS (UDP port 53)                       ${WHITE}│${NC}"
    echo -e "${WHITE}├─────────────────────────────────────────────────┤${NC}"
    printf  "${WHITE}│${NC}  %-15s : %-28s ${WHITE}│${NC}\n" "Source"      "$src"
    printf  "${WHITE}│${NC}  %-15s : %-28s ${WHITE}│${NC}\n" "Destination" "$dst"
    printf  "${WHITE}│${NC}  %-15s : %-28s ${WHITE}│${NC}\n" "Type"        "$type"
    printf  "${WHITE}│${NC}  %-15s : %-28s ${WHITE}│${NC}\n" "Contenu"     "$contenu"
    echo -e "${WHITE}└─────────────────────────────────────────────────┘${NC}"
    echo ""
}

fleche() {
    local src="$1" dst="$2" msg="$3"
    echo -e "  ${CYAN}${src}${NC}  ${YELLOW}──────────────────────────→${NC}  ${GREEN}${dst}${NC}"
    echo -e "           ${DIM}${msg}${NC}"
    sleep 0.6
}

fleche_retour() {
    local src="$1" dst="$2" msg="$3"
    echo -e "  ${GREEN}${src}${NC}  ${YELLOW}←──────────────────────────${NC}  ${CYAN}${dst}${NC}"
    echo -e "           ${DIM}${msg}${NC}"
    sleep 0.6
}

# ────────────────────────────────────────────────────────────
# Simulation : Résolution RÉCURSIVE
# ────────────────────────────────────────────────────────────

simulation_recursive() {
    banner "RÉSOLUTION DNS RÉCURSIVE — $DOMAIN"

    echo -e "${BOLD}Principe :${NC} Le résolveur fait TOUT le travail à la place du client."
    echo -e "           Le client envoie UNE seule requête et attend la réponse finale."
    echo ""
    separator
    sleep 1

    # Étape 1
    log_step 1 "Le CLIENT envoie une requête au Résolveur local (ex: serveur FAI)"
    afficher_paquet_dns "Client (192.168.1.10)" "Résolveur (8.8.8.8)" \
        "QUERY (Récursive)" "Qui est $DOMAIN ?"
    fleche "CLIENT" "RÉSOLVEUR" "Question: $DOMAIN → Adresse IP ?"
    sleep 0.5

    # Étape 2
    log_step 2 "Le Résolveur interroge un Serveur RACINE (.)"
    fleche "RÉSOLVEUR" "RACINE (.)" "Qui gère .com ?"
    fleche_retour "RACINE (.)" "RÉSOLVEUR" "→ Essaie les serveurs TLD .com (192.5.6.30)"
    sleep 0.5

    # Étape 3
    log_step 3 "Le Résolveur interroge le serveur TLD (.com)"
    fleche "RÉSOLVEUR" "TLD .com" "Qui gère google.com ?"
    fleche_retour "TLD .com" "RÉSOLVEUR" "→ Essaie ns1.google.com (216.239.32.10)"
    sleep 0.5

    # Étape 4
    log_step 4 "Le Résolveur interroge le serveur AUTORITAIRE de google.com"
    fleche "RÉSOLVEUR" "ns1.google.com" "Quelle est l'IP de $DOMAIN ?"
    fleche_retour "ns1.google.com" "RÉSOLVEUR" "→ $DOMAIN = 142.250.185.68 (TTL: 300s)"
    sleep 0.5

    # Étape 5
    log_step 5 "Le Résolveur retourne la réponse finale au CLIENT"
    fleche_retour "RÉSOLVEUR" "CLIENT" "→ $DOMAIN = 142.250.185.68 ✓"

    echo ""
    log_success "Résolution récursive terminée !"
    echo -e "  ${BOLD}Résultat :${NC} $DOMAIN → ${GREEN}142.250.185.68${NC}"
    echo -e "  ${DIM}Le résolveur met en cache ce résultat (TTL=300s)${NC}"
}

# ────────────────────────────────────────────────────────────
# Simulation : Résolution ITÉRATIVE
# ────────────────────────────────────────────────────────────

simulation_iterative() {
    banner "RÉSOLUTION DNS ITÉRATIVE — $DOMAIN"

    echo -e "${BOLD}Principe :${NC} C'est le CLIENT lui-même qui interroge chaque serveur."
    echo -e "           Chaque serveur lui indique vers qui aller ensuite."
    echo ""
    separator
    sleep 1

    log_step 1 "Le CLIENT interroge directement un Serveur RACINE (.)"
    afficher_paquet_dns "Client (192.168.1.10)" "Racine (198.41.0.4)" \
        "QUERY (Itérative)" "Qui est $DOMAIN ?"
    fleche "CLIENT" "RACINE (.)" "Qui est $DOMAIN ?"
    fleche_retour "RACINE (.)" "CLIENT" "→ Je ne sais pas. Demande au TLD .com (192.5.6.30)"
    sleep 0.5

    log_step 2 "Le CLIENT contacte lui-même le serveur TLD .com"
    fleche "CLIENT" "TLD .com (192.5.6.30)" "Qui est $DOMAIN ?"
    fleche_retour "TLD .com" "CLIENT" "→ Je ne sais pas. Demande à ns1.google.com (216.239.32.10)"
    sleep 0.5

    log_step 3 "Le CLIENT contacte le serveur AUTORITAIRE de google.com"
    fleche "CLIENT" "ns1.google.com" "Quelle est l'IP de $DOMAIN ?"
    fleche_retour "ns1.google.com" "CLIENT" "→ $DOMAIN = 142.250.185.68 (Réponse autoritaire ✓)"

    echo ""
    log_success "Résolution itérative terminée !"
    echo -e "  ${BOLD}Résultat :${NC} $DOMAIN → ${GREEN}142.250.185.68${NC}"
    echo -e "  ${DIM}Le client a fait 3 allers-retours lui-même${NC}"
}

# ────────────────────────────────────────────────────────────
# Simulation : Cache DNS
# ────────────────────────────────────────────────────────────

simulation_cache() {
    banner "SIMULATION DU CACHE DNS"

    echo -e "${BOLD}Principe :${NC} Une réponse DNS est mise en cache selon son TTL."
    echo -e "           Les requêtes suivantes n'ont pas besoin de refaire tout le chemin."
    echo ""

    # Initialiser cache
    echo "" > "$CACHE_FILE"

    simuler_requete() {
        local domain="$1" ip="$2" ttl="$3"

        echo ""
        echo -e "${BOLD}━━━ Requête pour : ${CYAN}$domain${NC}${BOLD} ━━━${NC}"

        # Chercher dans le cache
        local cache_hit
        cache_hit=$(grep "^$domain " "$CACHE_FILE" 2>/dev/null)

        if [ -n "$cache_hit" ]; then
            local cached_ip cached_ttl
            cached_ip=$(echo "$cache_hit" | awk '{print $2}')
            cached_ttl=$(echo "$cache_hit" | awk '{print $3}')
            echo -e "  ${GREEN}[CACHE HIT]${NC} Réponse trouvée en cache !"
            echo -e "  ${DIM}Pas besoin de contacter les serveurs DNS${NC}"
            echo -e "  Résultat : ${GREEN}$cached_ip${NC} (TTL restant: ${cached_ttl}s)"
        else
            log_warn "Cache MISS — Résolution DNS nécessaire..."
            pause "Interrogation des serveurs DNS"
            echo "$domain $ip $ttl" >> "$CACHE_FILE"
            echo -e "  ${GREEN}Réponse reçue :${NC} $domain → ${GREEN}$ip${NC}"
            echo -e "  ${DIM}Mis en cache pour ${ttl}s${NC}"
        fi
    }

    simuler_requete "$DOMAIN"       "142.250.185.68"  300
    simuler_requete "www.github.com" "140.82.112.4"    60
    simuler_requete "$DOMAIN"       "142.250.185.68"  300  # Cache hit !
    simuler_requete "www.github.com" "140.82.112.4"    60   # Cache hit !

    echo ""
    separator
    echo -e "${BOLD}  Contenu du cache DNS local :${NC}"
    separator
    echo -e "  ${DIM}DOMAINE                  IP               TTL${NC}"
    while IFS=' ' read -r d i t; do
        [ -z "$d" ] && continue
        printf "  ${CYAN}%-25s${NC} ${GREEN}%-16s${NC} ${YELLOW}%ss${NC}\n" "$d" "$i" "$t"
    done < "$CACHE_FILE"

    rm -f "$CACHE_FILE"
}

# ────────────────────────────────────────────────────────────
# Types d'enregistrements DNS
# ────────────────────────────────────────────────────────────

afficher_types_enregistrements() {
    banner "TYPES D'ENREGISTREMENTS DNS"

    echo -e "${WHITE}┌──────────┬──────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│${BOLD} Type     ${WHITE}│${NC}${BOLD} Description                                  ${WHITE}│${NC}"
    echo -e "${WHITE}├──────────┼──────────────────────────────────────────────┤${NC}"
    echo -e "${WHITE}│${NC} ${GREEN}A${NC}        ${WHITE}│${NC} Nom de domaine → Adresse IPv4               ${WHITE}│${NC}"
    echo -e "${WHITE}│${NC} ${GREEN}AAAA${NC}     ${WHITE}│${NC} Nom de domaine → Adresse IPv6               ${WHITE}│${NC}"
    echo -e "${WHITE}│${NC} ${GREEN}CNAME${NC}    ${WHITE}│${NC} Alias → autre nom de domaine                ${WHITE}│${NC}"
    echo -e "${WHITE}│${NC} ${GREEN}MX${NC}       ${WHITE}│${NC} Serveur de messagerie du domaine            ${WHITE}│${NC}"
    echo -e "${WHITE}│${NC} ${GREEN}NS${NC}       ${WHITE}│${NC} Serveur de noms autoritaire                 ${WHITE}│${NC}"
    echo -e "${WHITE}│${NC} ${GREEN}PTR${NC}      ${WHITE}│${NC} IP → Nom de domaine (résolution inverse)    ${WHITE}│${NC}"
    echo -e "${WHITE}│${NC} ${GREEN}TXT${NC}      ${WHITE}│${NC} Données texte (SPF, DKIM, vérification...)  ${WHITE}│${NC}"
    echo -e "${WHITE}│${NC} ${GREEN}SOA${NC}      ${WHITE}│${NC} Informations sur la zone DNS                ${WHITE}│${NC}"
    echo -e "${WHITE}└──────────┴──────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${DIM}  Exemple : $DOMAIN${NC}"
    echo -e "  ${CYAN}$DOMAIN${NC}    ${YELLOW}A${NC}      → ${GREEN}142.250.185.68${NC}         (IPv4)"
    echo -e "  ${CYAN}$DOMAIN${NC}    ${YELLOW}AAAA${NC}   → ${GREEN}2607:f8b0:4004:c09::68${NC} (IPv6)"
    echo -e "  ${CYAN}google.com${NC}          ${YELLOW}MX${NC}     → ${GREEN}aspmx.l.google.com${NC}     (Mail)"
    echo -e "  ${CYAN}mail.google.com${NC}     ${YELLOW}CNAME${NC}  → ${GREEN}googlemail.l.google.com${NC} (Alias)"
}

# ────────────────────────────────────────────────────────────
# Menu principal
# ────────────────────────────────────────────────────────────

menu_principal() {
    banner "SIMULATION DNS — Réseau & Système d'exploitation"
    echo -e "  ${BOLD}Domaine cible :${NC} ${CYAN}$DOMAIN${NC}"
    echo ""
    echo -e "  ${BOLD}1)${NC} Résolution récursive  (le résolveur fait tout)"
    echo -e "  ${BOLD}2)${NC} Résolution itérative  (le client fait tout)"
    echo -e "  ${BOLD}3)${NC} Cache DNS             (TTL et réutilisation)"
    echo -e "  ${BOLD}4)${NC} Types d'enregistrements DNS"
    echo -e "  ${BOLD}5)${NC} Tout afficher"
    echo -e "  ${BOLD}0)${NC} Quitter"
    echo ""
    echo -ne "  ${BOLD}Votre choix :${NC} "
    read -r choix

    case "$choix" in
        1) simulation_recursive ;;
        2) simulation_iterative ;;
        3) simulation_cache ;;
        4) afficher_types_enregistrements ;;
        5)
            simulation_recursive
            echo ""
            sleep 1
            simulation_iterative
            echo ""
            sleep 1
            simulation_cache
            echo ""
            sleep 1
            afficher_types_enregistrements
            ;;
        0) echo -e "\n${DIM}Au revoir !${NC}\n"; exit 0 ;;
        *) log_error "Choix invalide"; menu_principal ;;
    esac

    echo ""
    echo -ne "  ${DIM}Appuyez sur Entrée pour revenir au menu...${NC}"
    read -r
    menu_principal
}

menu_principal
