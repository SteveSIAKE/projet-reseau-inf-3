# Projet Réseau & Système d'exploitation
## Implémentation de protocoles réseau en Shell Script
### Environnement cible : Linux (Ubuntu/WSL2)

---

## Vue d'ensemble

Ce dépôt contient des scripts pédagogiques pour expliquer et manipuler plusieurs protocoles réseau :

- `ARP` : résolution `IP -> MAC`, cache ARP, sécurité (spoofing)
- `DHCP` : attribution dynamique d'adresses IP (processus DORA)
- `DNS` : résolution de noms de domaine (simulation + requêtes réelles)

Chaque protocole suit la même logique :

- un script de simulation visuelle (`*_sim.sh`)
- un script client interactif (`*_client.sh`)
- un script de démonstration complète (`*_demo.sh`)
- (selon protocole) un serveur simplifié (`*_server.sh`)

---

## Structure du projet

```text
projet-reseau-inf-3/
├── utils/
│   └── logger.sh                 # Logs colorés et helpers d'affichage
├── arp/
│   ├── arp_sim.sh                # Simulation visuelle ARP
│   ├── arp_client.sh             # Client ARP (ip neigh, ping)
│   └── arp_demo.sh               # Démo ARP guidée
├── dhcp/
│   ├── dhcp_server.sh            # Serveur DHCP simplifié (pool + baux)
│   ├── dhcp_sim.sh               # Simulation visuelle DORA/NAK/DECLINE
│   ├── dhcp_client.sh            # Client DHCP simplifié
│   └── dhcp_demo.sh              # Démo DHCP orchestrée
├── dns/
│   ├── dns_server.sh             # Serveur DNS simplifié
│   ├── dns_sim.sh                # Simulation visuelle DNS
│   ├── dns_client.sh             # Client DNS réel (dig, nslookup)
│   └── dns_demo.sh               # Démo DNS complète
└── README.md
```

---

## Prérequis

```bash
sudo apt update
sudo apt install -y \
  netcat-openbsd dnsutils tcpdump net-tools iproute2 iputils-ping
```

Rendre les scripts exécutables :

```bash
chmod +x utils/logger.sh
chmod +x arp/*.sh dhcp/*.sh dns/*.sh
```

---

## Lancement rapide

### ARP

```bash
cd arp
./arp_demo.sh
```

### DHCP

```bash
cd dhcp
./dhcp_demo.sh
```

### DNS

```bash
cd dns
./dns_demo.sh [domaine]   # ex: ./dns_demo.sh google.com
```

---

## Détails par protocole

### ARP — Address Resolution Protocol

- `arp_sim.sh` : ARP Request/Reply, cache hit, gratuitous ARP, spoofing
- `arp_client.sh` : consultation et actions réelles sur table ARP (`ip neigh`)
- `arp_demo.sh` : présentation guidée + exécution automatique de la simulation

Commandes utiles :

```bash
ip neigh show
ping -c 1 192.168.1.1
```

### DHCP — Dynamic Host Configuration Protocol

- `dhcp_server.sh` : gestion du pool, baux, réservations statiques
- `dhcp_sim.sh` : visualisation DORA + scénarios (renouvellement, NAK, DECLINE)
- `dhcp_client.sh` : client simplifié (discover/request/release)
- `dhcp_demo.sh` : orchestrateur de démo (serveur, client, simulation)

Fichiers d'état utilisés :

- `/tmp/dhcp_pool.txt`
- `/tmp/dhcp_baux.txt`
- `/tmp/dhcp_config.txt`

### DNS — Domain Name System

- `dns_sim.sh` : résolution récursive/itérative, cache TTL, types d'enregistrements
- `dns_client.sh` : requêtes réelles `A`, `AAAA`, `MX`, `NS`, `CNAME`, `PTR`
- `dns_server.sh` : serveur DNS local simplifié (zone fictive)
- `dns_demo.sh` : démonstration complète du protocole DNS

---

## Concepts couverts

| Protocole | Concepts |
|---|---|
| ARP | Broadcast, ARP Request/Reply, cache ARP, gratuitous ARP, spoofing |
| DHCP | DORA, baux, renouvellement T1/T2, release, NAK/DECLINE |
| DNS | Hiérarchie DNS, récursif vs itératif, TTL/cache, types d'enregistrements |

---

## Remarques

- Les scripts sont conçus pour Linux/WSL avec utilitaires réseau classiques.
- Certaines actions (ex: modification ARP statique) nécessitent `sudo`.
- Les sorties utilisent des couleurs ANSI via `utils/logger.sh`.

---

## Prochaines extensions

- `TCP` : handshake 3-way, états de connexion, simulation de flux
- `UDP` : datagrammes, pertes, retransmissions applicatives
