# Ricerca: cosa deve avere un'app fitness (e cosa manca)

> Fonti: roundup 2026 e analisi di recensioni 1-3 stelle (unstar.app, marlvel.ai), forum Whoop/Freeletics/AndroidCentral, confronti Hevy/Strong/Fitbod/Jefit. Molte sono blog di aziende concorrenti, quindi i numeri sono indicativi, non verificati. Da rifare con Reddit (r/fitness, r/bodyweightfitness, r/AppleWatch) e recensioni App Store dirette.

## 1. Le feature migliori delle app attuali (da rubare)

| App | Cosa fa meglio | Per noi |
|---|---|---|
| **Hevy / Strong** | Logging pesi velocissimo, "previous" accanto al set, rest timer, routine, PR automatici, grafici | Base del cuore dell'app |
| **Fitbod** | Programmazione adattiva per attrezzatura/recupero muscolare | Generazione allenamento + mappa muscolare |
| **Whoop / Oura** | Recovery, strain, sonno, HRV → "oggi quanto spingere" | Readiness score |
| **Strava** | Social, segmenti, feed, kudos, GPS | Amici + sfide leggere, GPS corsa dopo |
| **MyFitnessPal / Yazio** | Database cibo + barcode | Nutrizione, ma fatta meglio (vedi lamentele) |
| **Apple Fitness / Activity** | Anelli chiusi = dopamina, streak, celebrazioni | Anelli animati, streak |
| **Nike Run Club / Peloton** | Coaching audio, classi, motivazione | Fase 3 |
| **Freeletics / Jefit** | Piani, libreria esercizi enorme | Libreria con video/animazioni |
| **Apple Watch app** | Log dal polso senza prendere il telefono | Companion watchOS |

## 2. Cosa la gente lamenta (i buchi di mercato)

1. **Paywall aggressivi**: funzioni gratis per anni poi bloccate (barcode MFP). ~29% delle recensioni 1-3★ nei calorie tracker. Trial con carta, cancellazione difficile.
   → *Tracking di base SEMPRE gratis. Pro solo per cose "extra". Cancellazione in 1 tap.*
2. **Dati inaccurati**: database cibo sporco (banana 27 vs 200 kcal), GPS che sbanda.
   → *Database verificato, indicatore di confidenza, correzione facile.*
3. **Sync rotto** con Apple Watch / Garmin / Apple Health dopo ogni update iOS; manca sync **bidirezionale** con Salute.
   → *HealthKit bidirezionale, affidabile, con log di sync visibile.*
4. **Affidabilità/perdita dati** (Strong che cancella workout con >1000 sessioni).
   → *Local-first (SwiftData), backup iCloud, export CSV/JSON sempre.*
5. **Stagnazione**: app che non ricevono più feature.
6. **AI poco intelligente** (Fitbod: molti ignorano i suggerimenti).
   → *AI trasparente: spiega PERCHÉ propone quel carico.*
7. **Nessuna app usa davvero recovery (HRV/sonno) per adattare l'allenamento**. Gap consistente.
   → *Differenziatore principale.*
8. **Esercizi non standard / customizzazione limitata**, free tier con 3-4 routine.
   → *Esercizi custom illimitati, routine illimitate gratis.*
9. **Troppo complicate** (Jefit) vs utenti che vogliono solo peso/rep.
   → *Modalità "Semplice" e modalità "Avanzata" (progressive disclosure).*
10. **Preferiti/template, API/export dati** (Freeletics forum).
11. **Tutto-in-uno mancante**: allenamento + nutrizione + recupero in app diverse.

## 3. Feature set proposto

**MVP (fase 1 — in costruzione)**
- Home con anelli animati (Movimento / Allenamento / Recupero), streak, allenamento di oggi
- Logger allenamento rapido: previous, check set con haptic, rest timer automatico, PR detection con celebrazione
- Progressi: grafici volume/forza con animazione
- Design system + motion (molle, stagger, zoom transition, reduce motion)

**Fase 2**
- SwiftData + backup iCloud + export
- HealthKit bidirezionale (passi, sonno, HRV, workout)
- Readiness score e carico suggerito con spiegazione
- Libreria esercizi con animazioni, esercizi custom, routine illimitate
- Widget, Live Activity del rest timer, Dynamic Island
- Apple Watch companion

**Fase 3**
- Nutrizione (barcode, database verificato, foto → stima)
- Social leggero: amici, sfide, kudos
- GPS corsa/ciclismo
- Coach AI con spiegazioni, form check via camera
- Siri/App Intents ("inizia allenamento gambe")

## 4. Principi di prodotto
- **Gratis dove conta**: logging, routine, grafici, export. Mai rimuovere feature gratis già date.
- **Veloce**: un set loggato in ≤2 tap.
- **Dati tuoi**: local-first, export in qualsiasi momento.
- **Motion con scopo**: feedback, continuità spaziale, celebrazione. Mai decorazione che rallenta. Rispetta "Riduci movimento".
