#!/bin/bash
# ============================================================
#  arp_client.sh — Client ARP réel (ip neigh, arp, ping)
#  Consulte et manipule la table ARP locale
#  Projet Réseau & SE — Protocoles en Shell
# ============================================================

source "$(dirname "$0")/../utils/logger.sh"

IFACE_DEFAULT=$(ip route 2>/dev/null | awk '/default/ {print $5; exit}')

verifier_outils() {
    local outils=("ip" "ping")
    local manquants=()
    local o
    for o in "${outils[@]}"; do
        if ! command -v "$o" >/dev/null 2>&1; then
            manquants+=("$o")
        fi
    done

    if [ ${#manquants[@]} -gt 0 ]; then
        log_error "Outils manquants : ${manquants[*]}"
        log_info "Installe les utilitaires iproute2 / iputils-ping."
        exit 1
    fi
}

afficher_table_arp() {
    clear
    banner "TABLE ARP LOCALE"

    if ! ip neigh show >/dev/null 2>&1; then
        log_error "Impossible de lire la table ARP avec 'ip neigh'."
        return 1
    fi

    local table
    table=$(ip neigh show | sed '/^\s*$/d')
    if [ -z "$table" ]; then
        log_warn "Table ARP vide."
        echo ""
        return 0
    fi

    echo -e "${WHITE}┌──────────────────┬──────────────────────┬──────────────┬────────────┐${NC}"
    echo -e "${WHITE}│${BOLD} IP               ${WHITE}│${BOLD} MAC                  ${WHITE}│${BOLD} Interface    ${WHITE}│${BOLD} Etat       ${WHITE}│${NC}"
    echo -e "${WHITE}├──────────────────┼──────────────────────┼──────────────┼────────────┤${NC}"

    while IFS= read -r ligne; do
        [ -z "$ligne" ] && continue
        local ip mac dev etat couleur
        ip=$(echo "$ligne" | awk '{print $1}')
        dev=$(echo "$ligne" | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
        mac=$(echo "$ligne" | awk '{for(i=1;i<=NF;i++) if($i=="lladdr"){print $(i+1); exit}}')
        etat=$(echo "$ligne" | awk '{print $NF}')
        [ -z "$mac" ] && mac="(inconnu)"
        [ -z "$dev" ] && dev="-"

        case "$etat" in
            REACHABLE|PERMANENT) couleur="$GREEN" ;;
            STALE|DELAY|PROBE) couleur="$YELLOW" ;;
            FAILED|INCOMPLETE) couleur="$RED" ;;
            *) couleur="$CYAN" ;;
        esac

        printf "${WHITE}│${NC} ${CYAN}%-16s${NC} ${WHITE}│${NC} %-20s ${WHITE}│${NC} %-12s ${WHITE}│${NC} ${couleur}%-10s${NC} ${WHITE}│${NC}\n" \
               "$ip" "$mac" "$dev" "$etat"
    done <<< "$table"

    echo -e "${WHITE}└──────────────────┴──────────────────────┴──────────────┴────────────┘${NC}"
    echo ""
}

resoudre_ip() {
    clear
    banner "RESOLUTION ARP D'UNE IP"
    echo -ne "  IP cible (ex: 192.168.1.1) : "
    read -r ip_cible
    [ -z "$ip_cible" ] && { log_error "IP vide."; return 1; }

    log_step 1 "Ping court pour déclencher ARP si nécessaire"
    ping -c 1 -W 1 "$ip_cible" >/dev/null 2>&1

    log_step 2 "Lecture de l'entrée ARP"
    local entree
    entree=$(ip neigh show "$ip_cible" 2>/dev/null)
    if [ -z "$entree" ]; then
        log_warn "Aucune entrée ARP trouvée pour $ip_cible."
        echo ""
        return 1
    fi

    local mac dev etat
    mac=$(echo "$entree" | awk '{for(i=1;i<=NF;i++) if($i=="lladdr"){print $(i+1); exit}}')
    dev=$(echo "$entree" | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
    etat=$(echo "$entree" | awk '{print $NF}')
    [ -z "$mac" ] && mac="(inconnue)"

    log_success "Résolution ARP : $ip_cible -> $mac"
    printf "  ${CYAN}%-12s${NC}: %s\n" "Interface" "$dev"
    printf "  ${CYAN}%-12s${NC}: %s\n" "Etat" "$etat"
    echo ""
}

ajouter_entree_statique() {
    clear
    banner "AJOUT D'UNE ENTREE ARP STATIQUE"
    echo -e "  ${DIM}Nécessite généralement les privilèges administrateur.${NC}"
    echo ""

    local iface
    echo -ne "  Interface (Enter=$IFACE_DEFAULT) : "
    read -r iface
    [ -z "$iface" ] && iface="$IFACE_DEFAULT"

    echo -ne "  IP cible : "
    read -r ip_cible
    echo -ne "  MAC cible (format aa:bb:cc:dd:ee:ff) : "
    read -r mac_cible

    if [ -z "$iface" ] || [ -z "$ip_cible" ] || [ -z "$mac_cible" ]; then
        log_error "Paramètres incomplets."
        return 1
    fi

    if ip neigh replace "$ip_cible" lladdr "$mac_cible" nud permanent dev "$iface" 2>/dev/null; then
        log_success "Entrée ARP statique ajoutée : $ip_cible -> $mac_cible ($iface)"
    else
        log_error "Echec de l'ajout. Réessaie avec sudo."
        log_info "Commande: sudo ip neigh replace $ip_cible lladdr $mac_cible nud permanent dev $iface"
    fi
    echo ""
}

supprimer_entree() {
    clear
    banner "SUPPRESSION D'UNE ENTREE ARP"
    local iface
    echo -ne "  Interface (Enter=$IFACE_DEFAULT) : "
    read -r iface
    [ -z "$iface" ] && iface="$IFACE_DEFAULT"

    echo -ne "  IP à supprimer : "
    read -r ip_cible
    [ -z "$ip_cible" ] && { log_error "IP vide."; return 1; }

    if ip neigh del "$ip_cible" dev "$iface" 2>/dev/null; then
        log_success "Entrée supprimée : $ip_cible ($iface)"
    else
        log_error "Suppression impossible. Vérifie l'IP, l'interface ou les droits."
    fi
    echo ""
}

vider_table_dynamique() {
    clear
    banner "VIDAGE DES ENTREES ARP DYNAMIQUES"
    echo -e "  ${YELLOW}Attention${NC} : cette action peut perturber temporairement le trafic."
    echo -ne "  Confirmer (oui/non) : "
    read -r confirmation
    [ "$confirmation" != "oui" ] && { log_info "Action annulée."; echo ""; return 0; }

    if ip neigh flush all 2>/dev/null; then
        log_success "Table ARP vidée."
    else
        log_error "Echec du vidage. Essaie avec sudo."
        log_info "Commande: sudo ip neigh flush all"
    fi
    echo ""
}

menu() {
    verifier_outils

    while true; do
        clear
        banner "CLIENT ARP — Réseau & Système d'exploitation"
        echo -e "  ${BOLD}Interface par défaut :${NC} ${CYAN}${IFACE_DEFAULT:-inconnue}${NC}"
        echo ""
        echo -e "  ${BOLD}1)${NC} Afficher la table ARP"
        echo -e "  ${BOLD}2)${NC} Résoudre une IP (ping + ARP)"
        echo -e "  ${BOLD}3)${NC} Ajouter une entrée ARP statique"
        echo -e "  ${BOLD}4)${NC} Supprimer une entrée ARP"
        echo -e "  ${BOLD}5)${NC} Vider la table ARP dynamique"
        echo -e "  ${BOLD}0)${NC} Quitter"
        echo ""
        echo -ne "  ${BOLD}Choix :${NC} "
        read -r choix

        case "$choix" in
            1) afficher_table_arp ;;
            2) resoudre_ip ;;
            3) ajouter_entree_statique ;;
            4) supprimer_entree ;;
            5) vider_table_dynamique ;;
            0) echo -e "\n${DIM}Au revoir !${NC}\n"; exit 0 ;;
            *) log_error "Choix invalide" ;;
        esac

        echo -ne "  ${DIM}Entrée pour continuer...${NC}"
        read -r
    done
}

menu
