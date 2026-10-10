# Creazione allenamenti + cibo: ricerca e piano di integrazione

> Fonti in gran parte blog/vendor. Licenze e limiti API vanno verificati sui siti ufficiali prima di usarli. Uso previsto ora: solo io e un amico, quindi niente App Store.

## 1. Creazione allenamenti

**Stato attuale:** non esiste. C'è un solo allenamento di esempio fisso.

**Cosa serve (in ordine di priorità)**
1. **Libreria esercizi** con ricerca e filtri (muscolo, attrezzo), esercizi custom illimitati.
2. **Routine/template**: crea, duplica, riordina con drag & drop, "inizia da template".
3. **Selezione multipla** quando aggiungi esercizi (non un esercizio alla volta, lamentela tipica).
4. **Anteprima** immagine/video dell'esercizio prima di aggiungerlo.
5. **Superset**, note per esercizio, tempo di recupero per esercizio.
6. **Salva allenamento fatto come routine** ("ripeti quello di martedì").
7. Più avanti: generazione automatica guidata dal recupero (HRV/sonno) con spiegazione.

**Dati esercizi (da verificare le licenze)**
- *wger*: open source con API REST; il repo è AGPLv3, la licenza dei dati va controllata.
- *free-exercise-db* / dataset GitHub: circa 800-1300 esercizi con immagini e muscoli; licenza da controllare.
- *ExerciseDB* commerciale: a pagamento. *RepDB*: attribuzione obbligatoria e vieta di ridistribuire il dataset.
- Per uso privato in due persone il rischio è basso, ma conviene partire da un dataset aperto e importarlo una volta nel database locale (non chiamare API a runtime).

**Come integrarlo**
- SwiftData: `Exercise`, `Routine`, `RoutineExercise`, `WorkoutLog`, `SetLog`.
- Il `WorkoutSession` attuale diventa generato da una `Routine` invece che hardcoded.
- Lo `WorkoutSnapshot` per il Watch resta uguale: si genera dalla sessione.
- UI: tab "Allenamenti" (routine) → editor con `List` + `onMove`, sheet di ricerca con multi-selezione, animazioni di inserimento/riordino.

## 2. Cibo / nutrizione

**Cosa funziona nelle app migliori**
- *MacroFactor*: ricalcola ogni settimana le calorie in base a peso e assunzione reale (molto apprezzato). Difetti: costo, curva di apprendimento.
- *Cronometer*: micronutrienti, dati verificati.
- *Yazio*: budget calorico chiaro, log semplice.
- Lamentele: database crowdsourced con errori (MyFitnessPal), AI foto poco precisa su piatti regionali, funzioni AI dietro paywall, barcode a pagamento.

**Funzioni da avere**
1. Barcode scan veloce (gratis, sempre).
2. Ricerca alimenti + **recenti, preferiti, pasti salvati**.
3. Porzioni reali (i dati sono per 100 g; serve scalare alla porzione mangiata).
4. Obiettivi calorie/macro e riepilogo giornaliero con anelli animati.
5. Peso corporeo e trend (media mobile).
6. Scrittura su Salute (energia, proteine, carboidrati, grassi) in modo bidirezionale.
7. Dopo: obiettivo adattivo stile MacroFactor, foto → stima con conferma manuale, micronutrienti.

**Fonti dati**
- **Open Food Facts**: ottimo per prodotti confezionati e barcode (forte anche sui prodotti italiani), ma crowdsourced e rumoroso. Da verificare i termini API.
- **USDA FoodData Central**: API gratuita, CC0, dati curati per alimenti generici. Serve una API key gratuita.
- Strategia: barcode → Open Food Facts; ricerca di alimenti base → USDA; sempre con possibilità di correggere i valori a mano e salvarli come alimento personale.

**Come integrarlo**
- `FoodItem` (per 100 g + porzioni), `FoodEntry` (data, pasto, quantità), `NutritionGoal`, `WeightEntry` in SwiftData.
- Scanner: `DataScannerViewController` di VisionKit, avvolto in `UIViewControllerRepresentable`. Richiede dispositivo reale e permesso fotocamera.
- HealthKit: scrivere i tipi `dietaryEnergyConsumed`, `dietaryProtein`, `dietaryCarbohydrates`, `dietaryFatTotal`. Nota: questa parte non l'ho verificata nella ricerca, va letta dalla documentazione Apple.
- Cache locale di ogni alimento già cercato, così funziona offline.
- Home: l'anello "Movimento" resta, si aggiunge un riepilogo calorie/macro; la card allenamento può suggerire proteine mancanti.

## 3. Distribuzione per due persone
- **Gratis**: build da Xcode sul tuo iPhone con Apple ID gratuito. Limite noto (non verificato in ricerca): il profilo scade dopo 7 giorni e va reinstallato; serve un Mac.
- **TestFlight**: serve l'Apple Developer Program (99 $/anno). I build durano 90 giorni, i tester interni non richiedono revisione e arrivano quasi subito (confermato dalle fonti). È la strada comoda per far provare l'app al tuo amico.
- I dati dei due utenti restano separati e locali (nessun server). Per condividere allenamenti si può aggiungere CloudKit o l'export/import di un file.

## 4. Ordine di sviluppo proposto
1. SwiftData + modelli + export JSON (base di tutto).
2. Libreria esercizi + editor routine + sessione generata dalla routine.
3. Cibo: ricerca/barcode/diario/obiettivi.
4. HealthKit bidirezionale (cibo, peso, sonno, HRV).
5. Readiness score, Live Activity del recupero, widget.
