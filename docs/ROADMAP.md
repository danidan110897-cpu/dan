# Roadmap: verso un'app completa

Stato: ✅ fatto · 🟡 parziale · ⬜ da fare. "Fatto" = compila in CI; la prova su dispositivo reale è ancora da fare.

## Fatto / in corso
- ✅ Home: anelli animati, streak, card allenamento
- ✅ Sessione allenamento: set con haptic, rest timer, PR con coriandoli (dati di esempio)
- ✅ Progressi: grafico volume (dati di esempio)
- ✅ Apple Watch: sync serie in tempo reale, battito, allenamento salvato in Salute
- 🟡 Corpo: BMI, grasso corporeo (US Navy / stima da BMI), massa magra, BMR, TDEE, obiettivo calorico, macro, acqua, peso con trend. Salvataggio con UserDefaults (da migrare a SwiftData)

## Fase A: fondamenta
- ⬜ SwiftData: modelli, migrazioni, export/import JSON, backup iCloud
- ⬜ Libreria esercizi (import dataset aperto, ricerca, filtri, esercizi custom)
- ⬜ Editor routine (drag & drop, superset, note, recuperi) → la sessione nasce dalla routine
- ⬜ Storico allenamenti reale; grafici e PR calcolati dai dati veri

## Fase B: cibo
- ⬜ Diario pasti, ricerca (USDA), barcode (Open Food Facts + VisionKit), porzioni, preferiti, pasti salvati
- ⬜ Collegamento obiettivi del tab Corpo ↔ diario (rimasto di oggi)
- ⬜ Scrittura su Salute

## Fase C: AI
- ⬜ Interfaccia `WorkoutGenerator` con motore locale (Foundation Models) e, dopo, Claude via proxy
- ⬜ Guardrail deterministici (libreria, attrezzatura, limiti, infortuni)
- ⬜ Sostituzione esercizio, carico suggerito con motivazione

## Fase D: salute e recupero
- ⬜ HealthKit: sonno, HRV, battito a riposo, passi → readiness score
- ⬜ Foto progresso (salvate sul dispositivo), misure corporee nel tempo
- ⬜ Live Activity + Dynamic Island per il rest timer, widget

## Fase E: rifinitura
- ⬜ Onboarding animato, impostazioni, unità (kg/lb), tema, lingua
- ⬜ Accessibilità (Dynamic Type, VoiceOver), test automatici, prestazioni
- ⬜ Distribuzione a due persone (TestFlight)
