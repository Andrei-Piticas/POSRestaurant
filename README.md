
# 🧾 POS Demo (Point-of-Sale) - Soluzione Flutter per Ristorazione


---

## 🌟 Panoramica del Progetto

Questo progetto è una demo completa di un'applicazione **Point-of-Sale (POS)** sviluppata interamente in **Flutter**. È stata progettata per mostrare una soluzione robusta e moderna per la gestione degli ordini in ambienti di ristorazione (ristoranti, bar, caffetterie).

Il focus è sulla creazione di un'interfaccia utente intuitiva che gestisca l'intero ciclo di vita dell'ordine, dalla presa alla stampa dello scontrino, garantendo al contempo la persistenza locale dei dati.

---

## ✨ Funzionalità Chiave

L'applicazione include tutte le funzionalità essenziali per una gestione efficiente delle vendite:

* **Gestione Ordini Flessibile:** Supporto per la creazione e l'organizzazione di ordini per tavoli specifici e per ordini da asporto (**Takeaway**).
* **Inventario Centralizzato:** Sistema completo per aggiungere, modificare e categorizzare prodotti, inclusa la gestione di **modificatori** (es. extra, note speciali, aggiunte).
* **Stato Ordine Real-Time:** Tracciamento visuale degli articoli come **"In sospeso"** o **"Inviato in Cucina"** per una comunicazione chiara.
* **Generazione Ricevute:** Stampa simulata o visualizzazione di ricevute specifiche per la **cucina** e ricevute finali per il **cliente**.
* **Persistenza Locale:** Tutti i dati dell'inventario, dei tavoli e degli ordini aperti sono salvati in modo persistente sul dispositivo tramite la libreria `shared_preferences`.
* **Esperienza Utente Migliorata:** Funzionalità di **Theme Toggle** per passare rapidamente tra la modalità chiara e la modalità scura.

---

## 🛠️ Stack Tecnologico

Il progetto è costruito su uno stack moderno e orientato al mobile:

* **Framework:** **Flutter** (UI cross-platform).
* **Linguaggio:** **Dart**.
* **Persistenza:** `shared_preferences` per l'archiviazione di dati chiave-valore a livello locale.
* **Stile:** `google_fonts` per una tipografia personalizzata e pulita.

---

## 🚀 Come Eseguire la Demo

**Prerequisiti:** È necessario avere installato Flutter SDK (versione stabile).

1.  **Clonazione e dipendenze:**

    ```bash
    git clone https://github.com/Andrei-Piticas/POSRestaurant
    cd pos_demo
    flutter pub get
    ```

2.  **Avvio:** Esegui l'applicazione su un emulatore o un dispositivo fisico.

    ```bash
    flutter run
    ```

---
````
