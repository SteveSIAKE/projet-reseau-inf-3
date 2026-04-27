# Projet Réseau & Système d'exploitation
## Implémentation de Protocoles Réseau en Shell Script
### Environnement : Linux (Ubuntu/WSL2)

---

## Structure du projet

```
projet-reseau/
├── utils/
│   └── logger.sh              # Utilitaire de logs colorés (partagé)
├── dns/
│   ├── dns_sim.sh             # Simulation visuelle DNS (récursif/itératif/cache)
│   ├── dns_client.sh          # Client DNS réel (dig + requêtes types)
│   ├── dns_server.sh          # Serveur DNS simplifié (netcat UDP)
│   └── dns_demo.sh            # Démonstration complète tout-en-un
├── tcp/                       # (À venir)
└── udp/                       # (À venir)
```

---

## Prérequis

```bash
sudo apt update
sudo apt install -y netcat-openbsd dnsutils tcpdump net-tools iproute2
```

---

## DNS — Domain Name System

### Rendre les scripts exécutables

```bash
chmod +x utils/logger.sh
chmod +x dns/*.sh
```

### Lancer la démo complète

```bash
cd dns
./dns_demo.sh [domaine]           # Ex: ./dns_demo.sh google.com
```

### Simulation visuelle (résolution récursive/itérative/cache)

```bash
./dns_sim.sh [domaine]
```

### Client DNS réel

```bash
./dns_client.sh                   # Menu interactif
```

Requêtes supportées : A, AAAA, MX, NS, CNAME, PTR, trace complète

### Serveur DNS simplifié

```bash
./dns_server.sh [port]            # Port par défaut : 5353
```

Le serveur utilise une base de données locale (`/tmp/dns_db.txt`) avec une zone fictive `*.monsite.local`.

---

## Concepts couverts

| Concept | Script |
|---|---|
| Résolution récursive | `dns_sim.sh` option 1 |
| Résolution itérative | `dns_sim.sh` option 2 |
| Cache DNS / TTL | `dns_sim.sh` option 3 |
| Types d'enregistrements | `dns_sim.sh` option 4 |
| Requêtes A, AAAA, MX, NS, CNAME, PTR | `dns_client.sh` |
| Trace de résolution | `dns_client.sh` option 8 |
| Serveur DNS local | `dns_server.sh` |
| Structure paquet UDP/DNS | `dns_demo.sh` partie 4 |

---

## Protocoles à venir

- **TCP** : simulation 3-way handshake + échange réel
- **UDP** : envoi/réception de datagrammes + simulation perte paquets
