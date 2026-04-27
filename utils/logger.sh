#!/bin/bash
# ============================================================
#  logger.sh — Utilitaire de logs colorés partagé
#  Projet Réseau & SE — Protocoles en Shell
# ============================================================

# Couleurs ANSI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color (reset)

# Séparateur visuel
separator() {
    echo -e "${DIM}──────────────────────────────────────────────────────${NC}"
}

# Bannière de section
banner() {
    local title="$1"
    echo ""
    echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    printf "${BOLD}${BLUE}║${NC}  %-52s${BOLD}${BLUE}║${NC}\n" "$title"
    echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Niveaux de log
log_info()    { echo -e "${CYAN}[INFO]${NC}    $1"; }
log_success() { echo -e "${GREEN}[OK]${NC}      $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}    $1"; }
log_error()   { echo -e "${RED}[ERREUR]${NC}  $1"; }
log_send()    { echo -e "${MAGENTA}[ENVOI →]${NC} $1"; }
log_recv()    { echo -e "${GREEN}[← RECU]${NC}  $1"; }
log_step()    { echo -e "${YELLOW}[ETAPE $1]${NC} $2"; }
log_packet()  { echo -e "${WHITE}[PAQUET]${NC}  $1"; }
log_server()  { echo -e "${BLUE}[SERVEUR]${NC} $1"; }
log_client()  { echo -e "${MAGENTA}[CLIENT]${NC}  $1"; }

# Pause animée
pause() {
    local msg="${1:-Traitement en cours}"
    echo -ne "${DIM}${msg}${NC}"
    for i in 1 2 3; do
        sleep 0.4
        echo -ne "${DIM}.${NC}"
    done
    echo ""
}

# Timestamp
timestamp() {
    date '+%H:%M:%S.%3N'
}

log_time() {
    echo -e "${DIM}[$(timestamp)]${NC} $1"
}
