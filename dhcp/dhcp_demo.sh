#!/bin/bash
# ============================================================
#  dhcp_demo.sh — Démo complète DHCP (serveur + client + sim)
#  Orchestrateur de démonstration pour le projet DHCP
#  Projet Réseau & SE — Protocoles en Shell
# ============================================================

source "$(dirname "$0")/../utils/logger.sh"

BASE_DIR="$(dirname "$0")"
SERVER_SCRIPT="$BASE_DIR/dhcp_server.sh"
CLIENT_SCRIPT="$BASE_DIR/dhcp_client.sh"
SIM_SCRIPT="$BASE_DIR/dhcp_sim.sh"

SERVER_PID_FILE="/tmp/dhcp_demo_server.pid"

verifier_scripts() {
    local manquant=0
    for script in "$SERVER_SCRIPT" "$CLIENT_SCRIPT" "$SIM_SCRIPT"; do
        if [ ! -f "$script" ]; then
            log_error "Script introuvable : $script"
            manquant=1
        fi
    done

    if [ "$manquant" -ne 0 ]; then
        return 1
    fi

    chmod +x "$SERVER_SCRIPT" "$CLIENT_SCRIPT" "$SIM_SCRIPT" >/dev/null 2>&1
    return 0
}

lancer_serveur_fond() {
    if [ -f "$SERVER_PID_FILE" ]; then
        local pid
        pid=$(cat "$SERVER_PID_FILE")
        if ps -p "$pid" >/dev/null 2>&1; then
            log_info "Serveur DHCP déjà lancé (PID $pid)."
            return 0
        fi
    fi

    nohup "$SERVER_SCRIPT" >/tmp/dhcp_demo_server.log 2>&1 &
    echo "$!" > "$SERVER_PID_FILE"
    sleep 0.5
    log_success "Serveur DHCP lancé en arrière-plan (PID $(cat "$SERVER_PID_FILE"))."
    log_info "Logs serveur : /tmp/dhcp_demo_server.log"
}

arreter_serveur_fond() {
    if [ ! -f "$SERVER_PID_FILE" ]; then
        log_warn "Aucun serveur de démo en cours."
        return 0
    fi

    local pid
    pid=$(cat "$SERVER_PID_FILE")
    if ps -p "$pid" >/dev/null 2>&1; then
        kill "$pid" >/dev/null 2>&1
        log_success "Serveur DHCP arrêté (PID $pid)."
    else
        log_warn "Le PID $pid n'est plus actif."
    fi
    rm -f "$SERVER_PID_FILE"
}

scenario_rapide() {
    clear
    banner "DEMO RAPIDE DHCP — DORA + Etat"
    echo -e "  ${DIM}Ce scénario enchaîne : visualisation DORA, client DHCP, puis état des baux.${NC}"
    echo ""
    pause "Préparation de la démo"

    log_step 1 "Simulation visuelle (DORA)"
    "$SIM_SCRIPT" << 'EOF'
1

0
EOF

    log_step 2 "Client DHCP : obtention d'adresse"
    "$CLIENT_SCRIPT" << 'EOF'
1

3

0
EOF

    log_success "Scénario rapide terminé."
    echo ""
}

menu() {
    if ! verifier_scripts; then
        exit 1
    fi

    while true; do
        clear
        banner "DEMO DHCP — Réseau & Système d'exploitation"
        echo -e "  ${BOLD}Orchestration disponible :${NC}"
        echo ""
        echo -e "  ${BOLD}1)${NC} Lancer le serveur DHCP (avant-plan)"
        echo -e "  ${BOLD}2)${NC} Lancer le serveur DHCP (arrière-plan)"
        echo -e "  ${BOLD}3)${NC} Arrêter le serveur arrière-plan"
        echo -e "  ${BOLD}4)${NC} Lancer le client DHCP"
        echo -e "  ${BOLD}5)${NC} Lancer la simulation visuelle"
        echo -e "  ${BOLD}6)${NC} Exécuter un scénario rapide complet"
        echo -e "  ${BOLD}0)${NC} Quitter"
        echo ""
        echo -ne "  ${BOLD}Choix :${NC} "
        read -r choix

        case "$choix" in
            1) "$SERVER_SCRIPT" ;;
            2) lancer_serveur_fond ;;
            3) arreter_serveur_fond ;;
            4) "$CLIENT_SCRIPT" ;;
            5) "$SIM_SCRIPT" ;;
            6) scenario_rapide ;;
            0)
                echo ""
                log_info "Pense à arrêter le serveur en arrière-plan si nécessaire (option 3)."
                echo -e "\n${DIM}Au revoir !${NC}\n"
                exit 0
                ;;
            *) log_error "Choix invalide" ;;
        esac

        echo -ne "  ${DIM}Entrée pour revenir au menu...${NC}"
        read -r
    done
}

menu