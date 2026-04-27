#!/bin/bash
# ============================================================
#  dns_server.sh — Serveur DNS simplifié (texte via UDP/netcat)
#  Simule un serveur DNS avec une base de données locale
#  Usage : ./dns_server.sh [port]
#  Projet Réseau & SE — Protocoles en Shell
# ============================================================

source "$(dirname "$0")/../utils/logger.sh"

PORT="${1:-5353}"          # Port d'écoute (5353 évite sudo)
DB_FILE="/tmp/dns_db.txt"  # Base de données DNS locale
LOG_FILE="/tmp/dns_server.log"

# ────────────────────────────────────────────────────────────
# Base de données DNS locale (zone fictive)
# Format : DOMAINE TYPE VALEUR TTL
# ────────────────────────────────────────────────────────────

initialiser_base() {
    cat > "$DB_FILE" << 'EOF'
# Base de données DNS — Zone locale fictive
# Format : DOMAINE TYPE VALEUR TTL
www.monsite.local        A      192.168.1.10    300
mail.monsite.local       A      192.168.1.20    300
ftp.monsite.local        A      192.168.1.30    300
monsite.local            MX     mail.monsite.local  300
monsite.local            NS     ns1.monsite.local   86400
ns1.monsite.local        A      192.168.1.1     86400
www.monsite.local        AAAA   fe80::1         300
blog.monsite.local       CNAME  www.monsite.local   300
api.monsite.local        A      192.168.1.40    60
db.monsite.local         A      192.168.1.50    60
EOF
    log_success "Base de données DNS initialisée : $DB_FILE"
}

# ────────────────────────────────────────────────────────────
# Moteur de résolution DNS
# ────────────────────────────────────────────────────────────

resoudre() {
    local query="$1"
    local type="${2:-A}"
    local domain
    domain=$(echo "$query" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')

    # Chercher dans la base de données locale
    local resultat
    resultat=$(grep -v '^#' "$DB_FILE" | grep -v '^$' | \
               awk -v d="$domain" -v t="$type" \
               '$1 == d && $2 == t {print $3, $4}' 2>/dev/null)

    if [ -n "$resultat" ]; then
        local valeur ttl
        valeur=$(echo "$resultat" | awk '{print $1}')
        ttl=$(echo "$resultat" | awk '{print $2}')

        # Si c'est un CNAME, résoudre récursivement
        if [ "$type" = "CNAME" ]; then
            echo "REPONSE|$domain|CNAME|$valeur|$ttl"
        else
            echo "REPONSE|$domain|$type|$valeur|$ttl"
        fi
    else
        # Vérifier si le domaine existe avec un type différent
        local existe
        existe=$(grep -v '^#' "$DB_FILE" | grep -v '^$' | \
                 awk -v d="$domain" '$1 == d' 2>/dev/null | wc -l)

        if [ "$existe" -gt 0 ]; then
            echo "ERREUR|$domain|NOTYPE|Domaine connu mais pas d'enregistrement $type|0"
        else
            echo "ERREUR|$domain|NXDOMAIN|Domaine inconnu|0"
        fi
    fi
}

# ────────────────────────────────────────────────────────────
# Formater la réponse DNS
# ────────────────────────────────────────────────────────────

formater_reponse() {
    local reponse="$1"
    local statut
    statut=$(echo "$reponse" | cut -d'|' -f1)

    if [ "$statut" = "REPONSE" ]; then
        local domaine type valeur ttl
        domaine=$(echo "$reponse" | cut -d'|' -f2)
        type=$(echo "$reponse" | cut -d'|' -f3)
        valeur=$(echo "$reponse" | cut -d'|' -f4)
        ttl=$(echo "$reponse" | cut -d'|' -f5)

        cat << EOF
;; RÉPONSE DNS
;; QUESTION: $domaine IN $type
;; SECTION RÉPONSE:
$domaine    $ttl    IN  $type    $valeur
;; STATUS: NOERROR
EOF
    else
        local domaine code msg
        domaine=$(echo "$reponse" | cut -d'|' -f2)
        code=$(echo "$reponse" | cut -d'|' -f3)
        msg=$(echo "$reponse" | cut -d'|' -f4)

        cat << EOF
;; RÉPONSE DNS
;; QUESTION: $domaine
;; SECTION RÉPONSE: (vide)
;; STATUS: $code — $msg
EOF
    fi
}

# ────────────────────────────────────────────────────────────
# Afficher la base de données
# ────────────────────────────────────────────────────────────

afficher_base() {
    banner "BASE DE DONNÉES DNS LOCALE"
    echo -e "${WHITE}┌─────────────────────────┬───────┬───────────────────┬──────┐${NC}"
    echo -e "${WHITE}│${BOLD} Domaine                 ${WHITE}│${BOLD} Type  ${WHITE}│${BOLD} Valeur            ${WHITE}│${BOLD} TTL  ${WHITE}│${NC}"
    echo -e "${WHITE}├─────────────────────────┼───────┼───────────────────┼──────┤${NC}"

    grep -v '^#' "$DB_FILE" | grep -v '^$' | while read -r domaine type valeur ttl; do
        printf "${WHITE}│${NC} ${CYAN}%-23s${NC} ${WHITE}│${NC} ${YELLOW}%-5s${NC} ${WHITE}│${NC} ${GREEN}%-17s${NC} ${WHITE}│${NC} ${DIM}%-4s${NC} ${WHITE}│${NC}\n" \
               "$domaine" "$type" "$valeur" "$ttl"
    done

    echo -e "${WHITE}└─────────────────────────┴───────┴───────────────────┴──────┘${NC}"
    echo ""
}

# ────────────────────────────────────────────────────────────
# Ajouter un enregistrement à la base
# ────────────────────────────────────────────────────────────

ajouter_enregistrement() {
    echo -ne "  ${BOLD}Domaine  :${NC} "; read -r d
    echo -ne "  ${BOLD}Type     :${NC} "; read -r t
    echo -ne "  ${BOLD}Valeur   :${NC} "; read -r v
    echo -ne "  ${BOLD}TTL      :${NC} "; read -r l
    [ -z "$l" ] && l=300

    printf "%-25s %-6s %-20s %s\n" "$d" "$t" "$v" "$l" >> "$DB_FILE"
    log_success "Enregistrement ajouté : $d $t $v (TTL:$l)"
}

# ────────────────────────────────────────────────────────────
# Démarrer le serveur DNS (écoute UDP via netcat)
# ────────────────────────────────────────────────────────────

demarrer_serveur() {
    banner "SERVEUR DNS EN ÉCOUTE — Port $PORT/UDP"

    log_server "Démarrage du serveur DNS simplifié..."
    log_server "Port : $PORT/UDP"
    log_server "Base : $DB_FILE"
    log_server "Logs : $LOG_FILE"
    echo ""
    log_warn "Pour arrêter : Ctrl+C"
    separator
    echo ""

    # Boucle d'écoute
    while true; do
        # Lire une requête DNS texte via UDP
        local requete
        requete=$(nc -u -l -p "$PORT" -w 3 2>/dev/null)

        if [ -z "$requete" ]; then
            continue
        fi

        local horodatage
        horodatage=$(timestamp)

        # Parser la requête (format: TYPE NOM_DOMAINE)
        local type domaine
        type=$(echo "$requete" | awk '{print $1}' | tr '[:lower:]' '[:upper:]')
        domaine=$(echo "$requete" | awk '{print $2}' | tr '[:upper:]' '[:lower:]')

        # Gérer les cas simples
        if [ -z "$domaine" ]; then
            type="A"
            domaine=$(echo "$requete" | awk '{print $1}' | tr '[:upper:]' '[:lower:]')
        fi

        log_time "${CYAN}[REQUÊTE]${NC} $domaine ($type)"

        # Résoudre
        local resultat
        resultat=$(resoudre "$domaine" "$type")
        local reponse_fmt
        reponse_fmt=$(formater_reponse "$resultat")

        # Logger
        echo "[$horodatage] QUERY: $domaine ($type)" >> "$LOG_FILE"
        echo "[$horodatage] REPLY: $resultat" >> "$LOG_FILE"

        # Afficher résultat
        local statut
        statut=$(echo "$resultat" | cut -d'|' -f1)
        if [ "$statut" = "REPONSE" ]; then
            local valeur
            valeur=$(echo "$resultat" | cut -d'|' -f4)
            log_time "${GREEN}[RÉPONSE]${NC} $domaine → $valeur"
        else
            local code
            code=$(echo "$resultat" | cut -d'|' -f3)
            log_time "${RED}[ERREUR]${NC}  $domaine → $code"
        fi
    done
}

# ────────────────────────────────────────────────────────────
# Mode test : résolution directe sans réseau
# ────────────────────────────────────────────────────────────

mode_test() {
    banner "MODE TEST — Résolution directe"

    local domaines_test=(
        "www.monsite.local A"
        "mail.monsite.local A"
        "monsite.local MX"
        "monsite.local NS"
        "blog.monsite.local CNAME"
        "inconnu.local A"
        "www.monsite.local AAAA"
    )

    for item in "${domaines_test[@]}"; do
        local dom type_t
        dom=$(echo "$item" | cut -d' ' -f1)
        type_t=$(echo "$item" | cut -d' ' -f2)

        local res
        res=$(resoudre "$dom" "$type_t")
        local reponse_fmt
        reponse_fmt=$(formater_reponse "$res")

        echo -e "${BOLD}━━━ ${CYAN}$dom${NC}${BOLD} ($type_t) ━━━${NC}"
        echo "$reponse_fmt"
        sleep 0.2
    done
}

# ────────────────────────────────────────────────────────────
# Menu principal
# ────────────────────────────────────────────────────────────

menu() {
    banner "SERVEUR DNS SIMPLIFIÉ — Réseau & Système d'exploitation"
    echo -e "  ${BOLD}1)${NC} Démarrer le serveur DNS (port ${PORT}/UDP)"
    echo -e "  ${BOLD}2)${NC} Afficher la base de données DNS"
    echo -e "  ${BOLD}3)${NC} Ajouter un enregistrement"
    echo -e "  ${BOLD}4)${NC} Mode test (résolution locale sans réseau)"
    echo -e "  ${BOLD}5)${NC} Afficher les logs du serveur"
    echo -e "  ${BOLD}0)${NC} Quitter"
    echo ""
    echo -ne "  ${BOLD}Choix :${NC} "
    read -r choix

    case "$choix" in
        1) demarrer_serveur ;;
        2) afficher_base ;;
        3) ajouter_enregistrement ;;
        4) mode_test ;;
        5)
            if [ -f "$LOG_FILE" ]; then
                banner "LOGS DU SERVEUR DNS"
                cat "$LOG_FILE"
            else
                log_warn "Aucun log disponible (le serveur n'a pas encore tourné)"
            fi
            ;;
        0) echo -e "\n${DIM}Au revoir !${NC}\n"; exit 0 ;;
        *) log_error "Choix invalide" ;;
    esac

    echo ""
    echo -ne "  ${DIM}Appuyez sur Entrée pour continuer...${NC}"
    read -r
    menu
}

# Initialisation et lancement
initialiser_base
menu
