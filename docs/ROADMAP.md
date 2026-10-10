# Stato del progetto

Legenda: ✅ scritto e compila in CI · 🧪 coperto da test automatici · ⚠️ mai provato su dispositivo reale · ⬜ non fatto

La build e i test (iPhone, Watch e Live Activity inclusi) passano su GitHub Actions. **Nulla è ancora stato provato su un iPhone o Apple Watch veri**: la prova a casa serve a questo.

## Fatto
- ✅ Home: anelli (movimento, allenamento, recupero), serie settimanale, prossimo allenamento, impostazioni
- ✅ 🧪 Dati salvati sul telefono (SwiftData): routine, cronologia, cibo, foto
- ✅ Libreria di 60 esercizi, esercizi personalizzati, ricerca e filtri
- ✅ Editor routine: aggiungi più esercizi, riordina, superset, note, duplica
- ✅ Sessione allenamento reale: carichi dell'ultima volta, progressione automatica con motivazione, PR, timer di recupero, aggiungi serie
- ✅ Cronologia, progressi (volume settimanale, forza stimata 1RM, record)
- ✅ 🧪 Corpo: BMI, grasso (US Navy / stima), massa magra, BMR, TDEE, calorie e macro, acqua, trend peso e vita
- ✅ Foto progressi con confronto prima/dopo (solo sul telefono) ⚠️
- ✅ Cibo: diario per pasto, ricerca (Open Food Facts + USDA), scanner barcode, porzioni, preferiti, recenti, "copia da ieri", obiettivi dal tab Corpo ⚠️
- ✅ Salute: legge passi, calorie attive, sonno, HRV, battito a riposo; scrive cibo, peso, allenamenti ⚠️
- ✅ Recupero (readiness) con spiegazione dei fattori ⚠️
- ✅ 🧪 Creazione routine con AI: motori Regole, Apple Intelligence e Claude, più un controllo di sicurezza sempre attivo (esercizi esistenti, attrezzatura, infortuni, limiti di volume) ⚠️
- ✅ Apple Watch: serie in tempo reale, recupero, battito, allenamento in Salute ⚠️
- ✅ Live Activity + Dynamic Island per il timer di recupero ⚠️
- ✅ Onboarding animato, impostazioni, export JSON, cancellazione dati

## Limiti noti (onesti)
- ⬜ Backup iCloud/CloudKit: non fatto (richiede un account developer a pagamento). Per ora: export JSON dalle Impostazioni.
- ⬜ Widget sulla schermata Home e Siri/Shortcuts.
- ⬜ Unità in libbre, altre lingue oltre l'italiano.
- ⬜ Immagini/animazioni degli esercizi (la libreria è solo testo).
- ⬜ Piani nutrizionali adattivi stile MacroFactor, stima del cibo da foto.
- La chiamata a Claude, quelle a Open Food Facts/USDA e Apple Intelligence non sono mai state eseguite davvero: compilano, ma vanno provate.
- Apple Intelligence si compila solo con Xcode 26+; con Xcode più vecchi il motore risulta "non disponibile".
- La chiave USDA di default (DEMO_KEY) ha un limite di richieste.
- Il recupero e la qualità dei consigli AI sono stime, non indicazioni mediche.
