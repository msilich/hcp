# Anleitung fuer KI-Agenten

Diese Datei gilt fuer den gesamten Projektordner. Das Projekt enthaelt
OpenShift-/HyperShift-Manifeste, Betriebsanleitungen und Verwaltungsskripte.
Es gibt mehrere unabhaengige Cluster. Ein falscher Zielcluster kann laufende
Systeme beschaedigen. Die folgenden Regeln gelten auch fuer kleine lokale Modelle.

## 1. Bei jeder Aufgabe beachten

1. Lies den aktuellen Auftrag. Eine Analyse oder Dokumentationsaufgabe erlaubt
   keine Installation und keinen Neustart von Diensten.
2. Pruefe `git status --short`. Bestehende Aenderungen und geloeschte Dateien
   koennen vom Benutzer stammen. Nicht zuruecksetzen oder wiederherstellen.
3. Bestimme vor einem Clusterbefehl den Zielcluster und seine Kubeconfig.
   Nutze die im Auftrag genannte Datei. Verlasse dich nicht auf den Standardkontext.
4. Lies die passende README und die betroffenen Dateien. Fuehre darin enthaltene
   Befehle oder Skripte nicht allein deshalb aus, weil sie dort stehen.
5. Aendere nur, was der Auftrag erfordert. Bei einem klaren Reparaturauftrag
   arbeite bis zur Kontrolle des Ergebnisses weiter.
6. Fehlen Zielcluster, Zugang oder benoetigte Netzwerkwerte, benenne die Luecke.
   Erfinde keine IP, VLAN-ID, StorageClass, Zugangsdaten oder Testergebnisse.
7. Ein vorhandenes Manifest beweist keinen laufenden Dienst. Melde getrennt,
   was aus Dateien stammt und was du am Zielsystem geprueft hast.

## 2. Sprache und Antworten

- Antworte auf Deutsch, sachlich und mit konkreten Befunden.
- Verwende Standardsprache ohne Gendersprache, Beidnennungen,
  Gender-Sonderzeichen oder Ersatzformen wie "Mitarbeitende".
- Keine Emojis, Schmeicheleien, Floskeln oder kuenstlichen Gegenueberstellungen.
- Erklaere bei einer Aenderung kurz den Grund und das gepruefte Ergebnis.
  Sage auch, was nicht geprueft wurde.
- Wenn der Benutzer Befehle "als Text" verlangt, gib einzelne Befehle im Chat.
  Erstelle dafuer kein zusaetzliches Shellskript.

## 3. Wo du anfangen sollst

Alle Pfade in dieser Tabelle sind relativ zum Projektverzeichnis.

| Aufgabe | Zuerst lesen / zugehoerige Dateien |
| --- | --- |
| HCP-Lab `lab-hcp`, MetalLB und VLAN 12 | `manifests/hcp-lab-hcp-metallb-only/README.md` und einzelne Manifeste dieses Ordners |
| Kundenprojekt `cappx7` | `manifests/kunde-cappx7/README.md`, `ARCHITEKTUR.md` im selben Ordner und Abschnitt 5 unten |
| Aeltere HCP-Varianten | `manifests/hcp-lab-hcp-eno2/`, `manifests/hcp-lab-hcp-truenas/` |
| CloudStack-Management und CKS | `manifests/day2-cloudstack-management/README.md`, zugehoerige Manifeste und `scripts/cloudstack-*.sh` |
| CloudStack-Simulator | `manifests/day2-cloudstack-simulator/00-cloudstack-simulator.yaml` |
| TrueNAS CSI und RWX-Storage | `manifests/truenas-csi/README.md` und die nummerierten Manifeste |
| Harbor-Mirrors | `manifests/harbor-mirror-sets/00-harbor-proxy-cache-mirror-sets.yaml` |
| GitOps / OADP | `manifests/day2-gitops-backup/` |
| OpenShift Lightspeed | `manifests/day2-lightspeed/`; lokaler Provider und PostgreSQL-Konfiguration |
| AzerothCore / WoW | `manifests/wow/charts/azerothcore-playerbots/README.md`, Chart, `openshift/`, `playerbots-image/` unter `manifests/wow/` |
| JDownloader | `manifests/jdownloader/00-jdownloader.yaml` |
| NetBox-Inventar und Verkabelung | `scripts/*netbox*.py` |
| Hintergrund zur Lab-Topologie | `NETWORK_CURRENT.md`, `HCP_ARCHITECTURE_CURRENT.md`, `HCP_APPLY_ORDER_CURRENT.md`, `HCP_INSTALL_GUIDE.md`, `openshift-hcp-network-plan.html` |

Die Dokumente im Projektwurzelverzeichnis beschreiben teils aeltere Zustaende
aus Juni 2026. Auch ein Dateiname mit `CURRENT` ist kein Live-Nachweis.
Fuer Arbeiten an der MetalLB-only-Variante lies deren eigene README zuerst.
Mische ihre Konfiguration nicht mit alten VIP-Proxies aus anderen Ordnern.
Bei Widerspruechen pruefe den konkreten Zielzustand, bevor du etwas anwendest.

ZIP-Dateien, `*.before-*`, `.generated/`, `secrets-backup/` und Logdateien sind
Archive, Exporte oder Diagnosematerial. Sie sind kein Installationsplan.
Einzelne alte Manifeste sind unvollstaendige Patch-Payloads ohne `kind` oder
`metadata.name`; solche Payloads nicht mit `oc apply` wie volle Objekte behandeln.

## 4. Kubeconfig und Zielcluster pruefen

Lokaler Projektpfad: `/Users/Michael.Silich/git/hcp`.
Liegt dein Checkout woanders, verwende dessen Pfad statt des Mac-Pfads.
Die Zuordnung unten stammt aus den lokalen Dateien, nicht aus einem Live-Test.

| Kubeconfig im Projekt | Ziel laut Datei |
| --- | --- |
| `kubeconfig-noingress-letsencrypt` | Management-OpenShift: `https://api.shift.lost-aurora.de:6443`; bevorzugter Lab-Einstieg laut MetalLB-only-README |
| `kubeconfig-noingress-8`, `kubeconfig-noingress` | Ebenfalls Management-OpenShift; andere bzw. aeltere Zugangskonfigurationen |
| `lab-hcp-admin.kubeconfig` | Hosted-Cluster: `https://api.hcp.lost-aurora.de:6443` |
| `lab-hcp-admin.portforward.kubeconfig` | Lokaler Tunnel: `https://127.0.0.1:16443`; benoetigt einen passenden laufenden Tunnel |
| `cloudstack-cks-main.kubeconfig`, `cloudstack-cks-test-2.kubeconfig` | Beide Dateien zeigen auf `https://172.16.33.233:6443`; Namen beweisen keine getrennten Cluster |

Vor einer Live-Arbeit fuehre die folgenden lesenden Befehle aus.
Dieses Beispiel gilt fuer den Lab-Management-Cluster. Fuer ein anderes Ziel
setze `KC` auf die dazugehoerige Datei. Bei einem Fehler nicht weiter aendern.

```sh
KC=/Users/Michael.Silich/git/hcp/kubeconfig-noingress-letsencrypt
test -r "$KC"
oc --kubeconfig "$KC" config view --minify -o jsonpath='{.clusters[0].cluster.server}{"\n"}'
oc --kubeconfig "$KC" whoami
oc --kubeconfig "$KC" get nodes -o wide --request-timeout=20s
```

Nutze danach bei jedem `oc`-/`kubectl`-Befehl `--kubeconfig "$KC"` und bei
namespaced Ressourcen ein ausdrueckliches `-n`. Bei einem Zielwechsel pruefe
Server, Identitaet und Nodes erneut. Ein Namespace identifiziert keinen Cluster.
Bei `x509: certificate signed by unknown authority` pruefe Server und CA der
Kubeconfig. TLS-Pruefung nicht als dauerhafte Reparatur abschalten.

## 5. Management, Infrastruktur und Hosted-Cluster trennen

Ein `HostedCluster` und ein `NodePool` sind Custom Resources (CRs).
Eine CustomResourceDefinition (CRD) definiert dagegen den Ressourcentyp.
Die meisten YAML-Dateien hier enthalten CRs oder normale Kubernetes-Objekte.

Im Lab liegen `HostedCluster/lab-hcp` und `NodePool/workers` der MetalLB-only-
Variante im Management-Namespace `clusters-lab-hcp`. Die Control-Plane-Pods
laufen im Management-Namespace `clusters-lab-hcp-lab-hcp`. Guest-Worker und
Apps gehoeren zur API des Hosted-Clusters. Alte Varianten verwenden teilweise
einen anders benannten NodePool. Namen vor einer Aenderung auslesen.

Beim Kunden gibt es drei getrennte Ziele:

| Ordner unter `manifests/kunde-cappx7/` | Ziel | Gehoert dorthin |
| --- | --- | --- |
| `cmcmx1-management/` | Management-Cluster `cmcmx1` | Management-Netz, MetalLB fuer Control-Plane-VIPs, `IngressController/cappx7-routes`, HostedCluster und NodePool im Namespace `clusters` |
| `iappx1-infra/` | Virtualisierungscluster `iappx1` | Bond/VLAN/Bridge und NAD `cappx7/vlan225` fuer die Worker-VMs |
| `cappx7-hosted/` | Hosted-Cluster `cappx7` | Guest-MetalLB und Service `router-default-vlan225` fuer den vorhandenen Default-Router |

Die erzeugte Kunden-Control-Plane liegt auf `cmcmx1` in `clusters-cappx7`.
Der NodePool auf `cmcmx1` greift ueber `cappx7-infra-credentials` auf `iappx1` zu.
Die Kunden-Kubeconfigs muessen vom Benutzer bzw. der Kundenumgebung kommen;
verwende dafuer keine Lab-Kubeconfig.

OAuth und Ignition verwenden den HCP-Router auf dem Management-Cluster.
Console und Anwendungs-Routes verwenden den Router im Hosted-Cluster.
Beim Kunden existiert dort bereits `IngressController/default`; der Ordner
`cappx7-hosted/` veroeffentlicht ihn und erstellt keinen zweiten Controller.

## 6. Netzwerk- und Storage-Grenzen

- Lab: VLAN 12, Machine-Netz `172.16.3.0/24`; MetalLB-only-Plan mit
  Control-Plane-VIPs `.2-.5`, Guest-Ingress `.6` und Guest-Default-Router `.7`.
  API-/Konnectivity-Adressen aus den Services lesen, nicht aus der Tabelle raten.
  OPNsense ist im Plan die Grenze zum Default-Netz `172.16.1.0/24`.
- Kunde: VLAN 225, Machine-Netz `172.18.125.0/25`, MTU 9000.
  Management-VIPs: `.15` und `.19-.23`; Guest-VIPs: `.24-.30`;
  Management-Bridge: `.33`. DHCP darf diese Adressen nicht vergeben.
- Das Management-Interface `ens34` ist beim Kunden untagged angebunden.
  `iappx1` verwendet `bond1.225` tagged. Die Infra-NNCP enthaelt auch VLANs
  304-308; diese bei einer cappx7-Aenderung erhalten.
- Die NodePools verwenden `attachDefaultNetwork: false` und eine NAD.
  Nicht ungefragt eine Verbindung zum Default-/Management-Netz hinzufuegen.
- Eine VIP darf nicht gleichzeitig von Management- und Guest-MetalLB
  angekuendigt werden. Helper-Services muessen den passenden Router selektieren.
- Pruefe vor NNCP-, Routing-, MTU- oder Firewall-Aenderungen den betroffenen
  Zugangsweg und die Rueckfallmoeglichkeit. Aenderungen am produktiven Bond
  brauchen den im Kunden-README beschriebenen Wartungsrahmen.
- `primary-nfs-truenas` ist laut CloudStack-Betriebsplan der einzige gewuenschte
  Primary-Storage-Pool. `primary-nfs-kvm1` und lokale Primary Storage nicht
  ungefragt reaktivieren. Simulator und echtes CloudStack getrennt behandeln.
- `truenas-nfs-rwx` hat im Manifest `reclaimPolicy: Delete`.
  Das Loeschen eines PVC kann die Daten auf dem NAS loeschen.
  Aendere weder StorageClass noch PV/PVC, Dataset oder NFS-Share pauschal.

## 7. Fehler untersuchen und Aenderungen begrenzen

Lies zuerst den Status der betroffenen Ebene. Geeignete lesende Befehle sind:

```sh
oc --kubeconfig "$KC" get --raw='/readyz?verbose' --request-timeout=20s
oc --kubeconfig "$KC" get clusteroperators
oc --kubeconfig "$KC" -n openshift-console get pods,svc,route
oc --kubeconfig "$KC" -n openshift-ingress get pods,svc
oc --kubeconfig "$KC" -n openshift-ingress-operator get ingresscontroller
```

Bei einem HCP-Problem lies zusaetzlich HostedCluster/NodePool und Control-Plane-
Pods auf dem Management-Cluster sowie Nodes/Operatoren ueber die Guest-API.
Pruefe, ob HCP absichtlich pausiert ist oder Deployments auf null skaliert sind.
Setze diesen Zustand nicht allein wegen eines Health-Fehlers zurueck.

Bei einer Console-Stoerung pruefe DNS, TLS, Route, Service, EndpointSlices,
Router und Console-Pods. Bei API-Timeouts pruefe auch Node-/Storage-Probleme.
Ein blindes Neustarten von Console oder Router behebt keine ueberlastete etcd.

Vor einem Operator-Fix lies `ownerReferences`, die zustaendige CR, deren
Conditions und die Controller-Logs. Korrigiere den gewuenschten Zustand an der
verwaltenden CR, soweit der Operator ihn dort anbietet. Ein einzelner Wert wie
`doInstall: false` oder eine Prozentanzeige erklaert den Fehler noch nicht.

Ein Reparaturauftrag erlaubt die dafuer erforderlichen, begrenzten Aenderungen
am eindeutig bestimmten Ziel. Vor Loeschungen von Daten, einer Cluster-
Neuerstellung oder einer Ausweitung auf andere Systeme klaere den Umfang.
Keine globalen Restarts, pauschalen CSR-Freigaben, Finalizer-Loeschungen oder
Deaktivierungen von TLS, Webhooks und Zertifikatspruefungen als Standardreparatur.

Wende niemals `manifests/` oder `manifests/kunde-cappx7/` rekursiv mit einer
Kubeconfig an. Waehle einzelne Dateien gemaess der passenden README.
Dateinummern sind allein keine vollstaendige Apply-Reihenfolge.

## 8. Pruefen, ohne Betriebsskripte zu starten

Es gibt keinen zentralen Build- oder Testlauf fuer dieses gesamte Projekt.
Pruefe die geaenderten Dateien mit dem passenden Werkzeug.
Die folgenden Befehle sind Vorlagen: Ersetze Pfade mit tatsaechlichen Dateien.

```sh
# Shell: nur Syntax pruefen; das Skript wird nicht ausgefuehrt.
bash -n scripts/cloudstack-health-check.sh

# Python: Syntax parsen; kein Import und kein Start des Programms.
python3 -c 'import ast, pathlib; ast.parse(pathlib.Path("scripts/import_home_network_to_netbox.py").read_text())'

# Helm: lokaler Check des vorhandenen Charts.
helm lint manifests/wow/charts/azerothcore-playerbots
helm template wow manifests/wow/charts/azerothcore-playerbots -n wow >/dev/null

# Nur bei beauftragter Live-Arbeit am bereits geprueften Zielcluster:
# example.yaml durch ein vollstaendiges, passendes Manifest ersetzen.
oc --kubeconfig "$KC" apply --dry-run=server -f example.yaml -o name
oc --kubeconfig "$KC" diff -f example.yaml
```

`oc diff` liefert Exitcode 1 bei Unterschieden; hoehere Codes zeigen Fehler an.
Diffs koennen Secret-Inhalte zeigen. Pruefe Secret-Dateien separat und gib
deren Daten nicht im Chat oder in ungeschuetzten Logs aus.
Eine lokale Syntaxpruefung beweist weder CRD-Kompatibilitaet noch Live-Funktion.
Installiere kein neues Framework nur fuer eine einzelne Dokumentaenderung.

Die Python-NetBox-Werkzeuge schreiben per API; einige loeschen Objekte.
Fuehre sie nicht als Test aus. `--dry-run` existiert nur bei
`import_home_network_to_netbox.py` und benoetigt weiterhin Netzwerkzugriff,
Exportdateien und einen Token. Pruefe den Code vor Nutzung des Schalters.

Die CloudStack-Shellskripte benoetigen den passenden Linux-Zielhost.
DB-Backup, Restore-Test und RustFS-Policy-Sync schreiben Daten bzw. Policies;
der Restore-Test startet eine temporaere MySQL-Instanz. Nicht auf dem Mac starten.
Die Dateien `20-cks-csi-e2e.yaml`, `21-cks-csi-snapshot.yaml` und
`22-cks-csi-restore.yaml` gehoeren in den CKS-Cluster, obwohl sie unter
`day2-cloudstack-management/` liegen. Der erste Test setzt auch eine Default-
StorageClass; Umfang und Disk-Offering-ID vorher pruefen.

Nach einer Live-Aenderung pruefe die zugehoerigen Conditions, Ready-Pods und
Service-Endpunkte. Teste dann den angeforderten Ablauf, etwa Console-Aufruf,
VM-Start oder Lesen eines wiederhergestellten Volumes. `curl -k` beweist keine
gueltige Vertrauenskette. Ein erfolgreicher Apply beweist keine fertige Installation.

## 9. Zugangsdaten und Dateien schuetzen

- Kubeconfigs, Pull-Secrets, API-Keys, Passwoerter, private SSH-/TLS-Schluessel
  und deren Base64-Werte niemals in Antworten, neue Dokumente oder Commits kopieren.
- `oc config view --raw` und komplette Secret-YAMLs nicht ausgeben.
  Auch `last-applied-configuration`, Logs und ZIPs koennen Zugangsdaten enthalten.
- Besonders sensibel: `.generated/hcp1/pull-secret.json`, weitere Dateien unter
  `.generated/`, `secrets-backup/`, `lab-hcp-debug-ssh-key` und
  `manifests/hcp-lab-hcp-metallb-only/kunde/hcp-live-export.yaml`.
- `.gitignore` deckt nicht alle sensiblen Dateien ab. Kein `git add .`.
  Pruefe explizit ausgewaehlte Dateien vor einem Commit; committe nur bei Auftrag.
- Behandle exportierte YAMLs als Ausgangsmaterial. Entferne vor einer geplanten
  Wiederverwendung Server-Metadaten und Status; uebernimm keine fremden Secrets,
  UIDs oder Owner-Referenzen. Sichere Originale nicht ueberschreiben.
- Bewahre Secret-Exporte ausserhalb getrackter Dateien mit restriktiven
  Dateirechten auf. Erstelle fuer Dokumentation nur Platzhalter oder Secret-Referenzen.

Zum Abschluss nenne die geaenderten Dateien, das Ergebnis der passenden Pruefung
und offene Punkte. Behaupte keinen Clusterzugriff oder erfolgreichen Betrieb,
wenn du nur lokale Dateien geprueft hast.
