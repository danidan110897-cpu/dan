import Foundation
import UIKit

struct ExerciseGuide {
    let steps: [String]
    let mistakes: [String]
}

/// Short execution cues written for this app (not copied from any source). Photos live in Resources/Exercises.
enum ExerciseGuides {
    static func guide(for key: String) -> ExerciseGuide? { all[key] }

    private static func g(_ steps: [String], _ mistakes: [String]) -> ExerciseGuide {
        ExerciseGuide(steps: steps, mistakes: mistakes)
    }

    static let all: [String: ExerciseGuide] = [
        // Petto
        "bench_press": g(
            ["Sdraiati con occhi sotto il bilanciere, piedi ben piantati, scapole addotte e spalle basse.",
             "Afferra il bilanciere poco più largo delle spalle e staccalo a braccia tese.",
             "Scendi controllato fino a sfiorare la parte bassa del petto, con gomiti a circa 45-75° dal busto.",
             "Spingi verso l'alto riportando il bilanciere sopra le spalle."],
            ["Rimbalzare il bilanciere sul petto.", "Gomiti troppo aperti a 90°, che sovraccaricano le spalle.", "Staccare glutei o testa dalla panca."]),
        "incline_bench": g(
            ["Regola la panca a circa 30°, scapole addotte e piedi a terra.",
             "Stacca il bilanciere e portalo sopra la parte alta del petto.",
             "Scendi controllato fino alla clavicola bassa, poi spingi in verticale."],
            ["Inclinazione troppo alta: lavorano più le spalle del petto.", "Inarcare troppo la zona lombare.", "Scendere troppo velocemente."]),
        "db_bench": g(
            ["Siediti con i manubri sulle cosce, sdraiati e portali ai lati del petto.",
             "Spingi in alto fino a braccia quasi tese, manubri sopra le spalle.",
             "Scendi lentamente finché senti allungare il petto, gomiti leggermente sotto la linea delle spalle."],
            ["Manubri che si allargano troppo in basso.", "Spingere con i polsi piegati all'indietro.", "Peso così alto da perdere il controllo."]),
        "incline_db": g(
            ["Panca a circa 30°, manubri ai lati della parte alta del petto.",
             "Spingi verso l'alto avvicinando leggermente i manubri sopra al petto.",
             "Scendi con controllo, senza sollevare le spalle verso le orecchie."],
            ["Inclinazione eccessiva.", "Gomiti troppo larghi.", "Muovere le spalle in avanti a fine spinta."]),
        "chest_press": g(
            ["Regola il sedile in modo che le maniglie siano all'altezza del centro del petto.",
             "Schiena e testa appoggiate, spalle indietro e basse.",
             "Spingi fino quasi a distendere le braccia, poi torna lentamente."],
            ["Sedile troppo alto o basso.", "Staccare la schiena dallo schienale.", "Bloccare i gomiti con forza a fine corsa."]),
        "cable_fly": g(
            ["Posizionati al centro dei cavi, un piede avanti, busto leggermente inclinato in avanti.",
             "Con gomiti appena flessi porta le mani davanti al petto con un movimento ad arco.",
             "Stringi il petto un istante, poi torna indietro lentamente fino a sentire l'allungamento."],
            ["Trasformarlo in una spinta piegando molto i gomiti.", "Usare lo slancio del busto.", "Peso troppo alto che toglie ampiezza."]),
        "pec_deck": g(
            ["Regola il sedile: i gomiti devono stare all'altezza delle spalle.",
             "Spalle indietro e giù, petto in fuori.",
             "Chiudi le braccia davanti al petto, pausa breve, poi apri con controllo."],
            ["Spalle che salgono verso le orecchie.", "Aprire troppo oltre la linea del busto.", "Muoversi a scatti."]),
        "pushup": g(
            ["Mani leggermente più larghe delle spalle, corpo in linea retta da testa a talloni.",
             "Scendi finché il petto è a pochi centimetri da terra, gomiti a 45° circa.",
             "Spingi forte riportandoti su, senza perdere la linea del corpo."],
            ["Bacino che cede o si alza.", "Gomiti completamente aperti a T.", "Escursione troppo corta."]),
        "dips": g(
            ["Sulle parallele a braccia tese, busto leggermente inclinato in avanti.",
             "Scendi controllato finché le spalle sono circa all'altezza dei gomiti.",
             "Spingi per risalire senza dondolare."],
            ["Scendere troppo, caricando l'articolazione della spalla.", "Dondolare con le gambe.", "Spalle che salgono verso le orecchie."]),
        // Schiena
        "deadlift": g(
            ["Barra sopra il centro dei piedi, piedi larghi come i fianchi.",
             "Piegati ai fianchi, afferra la barra, schiena neutra, petto in fuori.",
             "Spingi il pavimento con le gambe tenendo la barra vicina al corpo, fino a stare in piedi.",
             "Rimetti giù con controllo spingendo i fianchi indietro."],
            ["Schiena incurvata.", "Barra lontana dalle gambe.", "Strappare la barra da terra anziché tenderla prima."]),
        "pullup": g(
            ["Presa poco più larga delle spalle, braccia distese, spalle attive.",
             "Tira i gomiti verso i fianchi finché il mento supera la sbarra.",
             "Scendi lentamente fino alla distensione completa."],
            ["Dondolare per prendere slancio.", "Escursione parziale.", "Spalle alle orecchie in basso."]),
        "lat_pulldown": g(
            ["Regola il cuscino sulle cosce, presa più larga delle spalle.",
             "Busto leggermente inclinato indietro, petto in fuori.",
             "Tira la barra verso la parte alta del petto portando i gomiti in basso.",
             "Risali lentamente fino a braccia distese."],
            ["Tirare la barra dietro la nuca.", "Dondolare con il busto.", "Usare solo le braccia."]),
        "barbell_row": g(
            ["Piedi larghi come i fianchi, busto inclinato a circa 45°, schiena neutra.",
             "Tira il bilanciere verso l'ombelico portando i gomiti indietro.",
             "Scendi controllato mantenendo la posizione del busto."],
            ["Schiena incurvata.", "Rialzare il busto a ogni ripetizione.", "Tirare con le braccia invece che con la schiena."]),
        "db_row": g(
            ["Appoggia una mano e un ginocchio sulla panca, schiena piatta.",
             "Tira il manubrio verso l'anca portando il gomito indietro.",
             "Scendi lentamente fino a braccio disteso, senza ruotare il busto."],
            ["Ruotare il tronco per sollevare più peso.", "Tirare verso la spalla.", "Testa che si alza o si abbassa troppo."]),
        "seated_row": g(
            ["Seduto con ginocchia leggermente flesse, petto in fuori, schiena neutra.",
             "Tira la maniglia verso l'addome portando le scapole insieme.",
             "Torna avanti lentamente senza arrotondare la schiena."],
            ["Dondolare avanti e indietro.", "Spalle sollevate.", "Fermarsi prima della piena estensione."]),
        "face_pull": g(
            ["Fune all'altezza del viso, presa con i pollici verso di te.",
             "Tira verso il viso aprendo i gomiti ai lati, mani oltre le orecchie.",
             "Ritorna lentamente senza perdere la postura."],
            ["Peso troppo pesante e busto che si inclina indietro.", "Gomiti bassi.", "Muoversi a scatti."]),
        "back_ext": g(
            ["Appoggia i fianchi sul supporto, caviglie bloccate, corpo in linea.",
             "Scendi piegando i fianchi con schiena neutra.",
             "Risali fino a tornare in linea retta, senza inarcare."],
            ["Iperestendere la zona lombare in alto.", "Scendere troppo velocemente.", "Slancio dalle gambe."]),
        // Spalle
        "ohp": g(
            ["In piedi, bilanciere sulle clavicole, gomiti leggermente avanti, glutei e addome contratti.",
             "Spingi il bilanciere sopra la testa spostando la testa leggermente indietro, poi in avanti.",
             "Blocca in alto con bilanciere sopra le spalle, poi scendi controllato."],
            ["Inarcare la schiena.", "Gomiti troppo indietro.", "Spingere con le gambe senza volerlo."]),
        "db_shoulder_press": g(
            ["Seduto con schienale, manubri all'altezza delle spalle, gomiti sotto i polsi.",
             "Spingi in alto fino quasi a distendere le braccia.",
             "Scendi lentamente fino a gomiti circa a 90°."],
            ["Gomiti troppo larghi.", "Inarcare la zona lombare.", "Battere i manubri in alto."]),
        "lateral_raise": g(
            ["In piedi, manubri ai lati, gomiti leggermente flessi.",
             "Solleva le braccia ai lati fino all'altezza delle spalle, polsi in linea.",
             "Scendi lentamente, senza far dondolare il busto."],
            ["Peso troppo alto e slancio.", "Salire oltre le spalle con i trapezi.", "Polsi più alti dei gomiti."]),
        "cable_lateral": g(
            ["Di lato al cavo basso, mano lontana dal cavo sull'impugnatura.",
             "Solleva il braccio di lato fino all'altezza della spalla.",
             "Scendi lentamente mantenendo la tensione."],
            ["Appoggiarsi con il busto.", "Spalla che sale verso l'orecchio.", "Strappi."]),
        "rear_delt_fly": g(
            ["Busto inclinato in avanti con schiena neutra, manubri sotto di te.",
             "Apri le braccia ai lati con gomiti leggermente flessi, fino all'altezza delle spalle.",
             "Torna giù lentamente."],
            ["Usare lo slancio del busto.", "Tirare con i dorsali invece dei deltoidi posteriori.", "Peso troppo alto."]),
        "shrug": g(
            ["In piedi con manubri ai lati, braccia distese.",
             "Alza le spalle verso le orecchie, pausa breve.",
             "Scendi lentamente."],
            ["Ruotare le spalle in cerchio.", "Piegare i gomiti per aiutarsi.", "Testa che sporge in avanti."]),
        // Bicipiti
        "barbell_curl": g(
            ["In piedi, bilanciere in presa supina larga come le spalle, gomiti ai fianchi.",
             "Fletti i gomiti portando il bilanciere verso le spalle senza muovere i gomiti.",
             "Scendi lentamente fino alla distensione."],
            ["Dondolare con il busto.", "Gomiti che vanno avanti.", "Polsi piegati."]),
        "db_curl": g(
            ["In piedi, manubri ai lati con palmi in avanti.",
             "Fletti un gomito alla volta, tenendo il gomito fermo.",
             "Scendi lentamente fino alla distensione."],
            ["Usare lo slancio.", "Ruotare il polso troppo presto.", "Spalle che si alzano."]),
        "hammer_curl": g(
            ["Manubri ai lati con palmi rivolti verso le gambe.",
             "Fletti i gomiti mantenendo i palmi in questa posizione.",
             "Scendi lentamente."],
            ["Dondolare con il busto.", "Gomiti che si spostano avanti.", "Escursione corta."]),
        "preacher_curl": g(
            ["Siediti con le braccia sul cuscino, ascelle a contatto.",
             "Fletti portando il peso verso le spalle.",
             "Scendi lentamente senza far cadere il peso in basso."],
            ["Sollevare i gomiti dal cuscino.", "Scendere di colpo in fondo, rischiando il tendine.", "Peso eccessivo."]),
        "cable_curl": g(
            ["Di fronte al cavo basso con barra o corda, gomiti ai fianchi.",
             "Fletti portando le mani verso le spalle.",
             "Torna lentamente mantenendo la tensione."],
            ["Gomiti che vanno avanti.", "Appoggiarsi indietro per sollevare.", "Strappi."]),
        // Tricipiti
        "pushdown": g(
            ["Davanti al cavo alto, gomiti vicini ai fianchi, busto leggermente inclinato in avanti.",
             "Spingi giù fino a distendere i gomiti, senza muovere le spalle.",
             "Risali lentamente fino a circa 90° di flessione."],
            ["Gomiti che si allontanano dal corpo.", "Usare il peso del corpo per spingere.", "Escursione corta."]),
        "skullcrusher": g(
            ["Sdraiato, bilanciere a braccia tese sopra il petto.",
             "Piega solo i gomiti portando il peso verso la fronte o dietro la testa.",
             "Estendi i gomiti tornando su, con gomiti fermi."],
            ["Gomiti che si aprono.", "Peso troppo alto e perdita di controllo.", "Muovere le spalle."]),
        "overhead_ext": g(
            ["In piedi o seduto con un manubrio tenuto con due mani sopra la testa.",
             "Piega i gomiti portando il peso dietro la testa, gomiti vicini alle orecchie.",
             "Estendi riportando il peso in alto."],
            ["Gomiti molto larghi.", "Inarcare la schiena.", "Scendere troppo velocemente."]),
        "close_grip_bench": g(
            ["Sdraiato, presa poco più stretta delle spalle.",
             "Scendi con i gomiti vicini ai fianchi fino al petto.",
             "Spingi su estendendo i gomiti."],
            ["Presa troppo stretta, che stressa i polsi.", "Gomiti aperti.", "Rimbalzare sul petto."]),
        "bench_dip": g(
            ["Mani sul bordo della panca dietro di te, gambe avanti.",
             "Piega i gomiti scendendo con il bacino vicino alla panca.",
             "Spingi su fino a distendere i gomiti."],
            ["Scendere troppo in basso, caricando le spalle.", "Spalle in avanti.", "Gomiti larghi."]),
        // Gambe
        "squat": g(
            ["Bilanciere sui trapezi, piedi larghi come le spalle, punte leggermente aperte.",
             "Inspira, irrigidisci l'addome e scendi spingendo i fianchi indietro e le ginocchia in linea con i piedi.",
             "Scendi finché le cosce sono almeno parallele, poi spingi sui piedi per risalire."],
            ["Ginocchia che cedono verso l'interno.", "Talloni che si sollevano.", "Busto che si piega troppo in avanti."]),
        "front_squat": g(
            ["Bilanciere sulle spalle anteriori, gomiti alti.",
             "Scendi verticale, busto eretto, ginocchia in linea con i piedi.",
             "Spingi su mantenendo i gomiti alti."],
            ["Gomiti che scendono.", "Talloni che si staccano.", "Schiena che si arrotonda."]),
        "leg_press": g(
            ["Schiena e bacino ben appoggiati, piedi larghi come le spalle sulla pedana.",
             "Scendi controllato finché le ginocchia sono a circa 90°.",
             "Spingi senza bloccare del tutto le ginocchia."],
            ["Bacino che si stacca dallo schienale.", "Ginocchia verso l'interno.", "Bloccare le ginocchia in alto."]),
        "leg_ext": g(
            ["Regola lo schienale e il rullo sopra le caviglie.",
             "Estendi le ginocchia fino a distendere le gambe.",
             "Scendi lentamente."],
            ["Slancio.", "Sollevare il bacino dal sedile.", "Carico eccessivo."]),
        "lunge": g(
            ["In piedi con manubri ai lati, fai un passo lungo in avanti.",
             "Scendi finché entrambe le ginocchia sono a circa 90°, busto eretto.",
             "Spingi sul piede avanti per tornare alla posizione iniziale."],
            ["Ginocchio che supera molto la punta del piede.", "Busto inclinato in avanti.", "Passo troppo corto."]),
        "bulgarian": g(
            ["Piede posteriore appoggiato su una panca, piede anteriore avanti.",
             "Scendi verticale piegando il ginocchio davanti.",
             "Spingi sul piede davanti per risalire."],
            ["Piede avanti troppo vicino alla panca.", "Ginocchio che cede all'interno.", "Busto troppo inclinato."]),
        "goblet": g(
            ["Tieni il kettlebell o manubrio al petto con gomiti sotto.",
             "Scendi tra le ginocchia, petto alto.",
             "Spingi sui piedi per risalire."],
            ["Talloni che si staccano.", "Schiena arrotondata.", "Ginocchia verso l'interno."]),
        "hack_squat": g(
            ["Schiena appoggiata, piedi sulla pedana a larghezza spalle.",
             "Scendi controllato fino a circa 90°.",
             "Spingi per risalire senza bloccare le ginocchia."],
            ["Bacino che si stacca.", "Ginocchia verso l'interno.", "Corsa troppo breve."]),
        "rdl": g(
            ["In piedi con il bilanciere, ginocchia appena flesse.",
             "Spingi i fianchi indietro facendo scendere il bilanciere lungo le gambe, schiena neutra.",
             "Scendi finché senti allungare i femorali, poi spingi i fianchi avanti per risalire."],
            ["Schiena arrotondata.", "Piegare troppo le ginocchia.", "Bilanciere lontano dalle gambe."]),
        "db_rdl": g(
            ["In piedi con due manubri davanti alle cosce, ginocchia appena flesse.",
             "Spingi i fianchi indietro facendo scendere i manubri lungo le gambe.",
             "Risali spingendo i fianchi avanti."],
            ["Schiena arrotondata.", "Manubri lontani dal corpo.", "Piegare troppo le ginocchia."]),
        "leg_curl": g(
            ["Regola il rullo sopra i talloni e il sedile.",
             "Fletti le ginocchia portando i talloni verso i glutei.",
             "Torna lentamente."],
            ["Slancio.", "Sollevare il bacino.", "Peso troppo alto."]),
        // Glutei
        "hip_thrust": g(
            ["Schiena alta appoggiata su una panca, bilanciere sui fianchi, piedi a terra.",
             "Spingi i fianchi in alto fino a corpo in linea tra spalle e ginocchia.",
             "Contrai i glutei in alto, poi scendi controllato."],
            ["Inarcare la zona lombare in alto.", "Piedi troppo lontani o vicini.", "Mento che si alza."]),
        "glute_bridge": g(
            ["Sdraiato con ginocchia piegate e piedi a terra.",
             "Spingi i fianchi in alto contraendo i glutei.",
             "Scendi lentamente senza appoggiare del tutto."],
            ["Inarcare la schiena.", "Spingere solo con la zona lombare.", "Piedi troppo vicini ai glutei."]),
        "cable_kickback": g(
            ["Caviglia agganciata al cavo basso, mani appoggiate davanti per stabilità.",
             "Porta la gamba indietro contraendo il gluteo.",
             "Torna lentamente senza ruotare il bacino."],
            ["Inarcare la schiena.", "Ruotare il bacino.", "Slancio."]),
        "abductor": g(
            ["Siediti con la schiena appoggiata, ginocchia contro i cuscini.",
             "Apri le gambe con controllo.",
             "Chiudi lentamente senza far battere i pesi."],
            ["Slancio.", "Staccare la schiena.", "Carico eccessivo."]),
        // Polpacci
        "standing_calf": g(
            ["In piedi sulla pedana con la parte anteriore dei piedi, spalle sotto i cuscini.",
             "Sali sulle punte il più possibile, pausa breve.",
             "Scendi lentamente fino ad allungare i polpacci."],
            ["Escursione corta.", "Rimbalzare in fondo.", "Piegare le ginocchia."]),
        "seated_calf": g(
            ["Seduto con i cuscini sulle ginocchia, parte anteriore dei piedi sulla pedana.",
             "Sali sulle punte il più possibile.",
             "Scendi lentamente fino a sentire l'allungamento."],
            ["Rimbalzare.", "Corsa parziale.", "Peso troppo alto."]),
        // Addome
        "plank": g(
            ["Avambracci a terra con gomiti sotto le spalle, corpo in linea.",
             "Contrai addome e glutei, sguardo in basso.",
             "Mantieni la posizione respirando regolarmente."],
            ["Bacino che cede o sale.", "Trattenere il respiro.", "Collo che si flette."]),
        "crunch": g(
            ["Sdraiato con ginocchia piegate, mani leggere dietro la testa.",
             "Solleva spalle e parte alta della schiena accorciando l'addome.",
             "Scendi lentamente senza appoggiare del tutto."],
            ["Tirare il collo con le mani.", "Alzarsi troppo con il busto.", "Slancio."]),
        "hanging_leg": g(
            ["Appeso alla sbarra, spalle attive, corpo fermo.",
             "Solleva le gambe contraendo l'addome, ginocchia o gambe tese.",
             "Scendi lentamente senza dondolare."],
            ["Dondolare.", "Usare solo i flessori dell'anca.", "Spalle alle orecchie."]),
        "cable_crunch": g(
            ["In ginocchio sotto il cavo alto con la corda ai lati della testa.",
             "Fletti la colonna avvicinando gomiti e ginocchia.",
             "Risali lentamente."],
            ["Tirare con le braccia.", "Muovere solo i fianchi.", "Peso troppo alto."]),
        "russian_twist": g(
            ["Seduto con busto inclinato indietro e piedi appoggiati o sollevati.",
             "Ruota il busto da un lato all'altro portando le mani vicino al fianco.",
             "Mantieni la schiena lunga e il petto aperto."],
            ["Schiena arrotondata.", "Muovere solo le braccia.", "Andare troppo veloce."]),
        "ab_wheel": g(
            ["In ginocchio con la ruota davanti, addome contratto.",
             "Rotola in avanti finché senti il controllo, schiena neutra.",
             "Torna indietro contraendo l'addome."],
            ["Inarcare la schiena.", "Andare troppo lontano all'inizio.", "Bacino che cede."]),
        // Corpo intero
        "kb_swing": g(
            ["In piedi con kettlebell davanti, piedi più larghi dei fianchi.",
             "Spingi i fianchi indietro e fai passare il kettlebell tra le gambe.",
             "Estendi i fianchi con forza portando il kettlebell all'altezza del petto."],
            ["Fare uno squat invece di una spinta di fianchi.", "Sollevare con le braccia.", "Schiena arrotondata."]),
        "burpee": g(
            ["In piedi, scendi in appoggio sulle mani.",
             "Porta i piedi indietro in posizione di flessione, esegui una flessione.",
             "Riporta i piedi sotto il corpo e salta in alto."],
            ["Bacino che cede nella flessione.", "Atterraggio brusco.", "Andare troppo veloce perdendo la tecnica."]),
        "farmer_walk": g(
            ["Raccogli due manubri pesanti, schiena neutra.",
             "Cammina con passi controllati, petto alto, spalle basse.",
             "Appoggia i pesi con controllo a fine serie."],
            ["Inclinarsi di lato.", "Spalle alle orecchie.", "Passi troppo veloci."]),
        // Cardio
        "treadmill": g(
            ["Parti con 5 minuti di riscaldamento a ritmo facile.",
             "Mantieni postura eretta, sguardo avanti, braccia rilassate.",
             "Concludi con 3-5 minuti di defaticamento."],
            ["Aggrapparsi al corrimano.", "Passi troppo lunghi.", "Partire subito a ritmo alto."]),
        "bike": g(
            ["Regola la sella: gamba quasi distesa nel punto più basso.",
             "Pedala con ritmo regolare, schiena neutra.",
             "Aumenta la resistenza gradualmente."],
            ["Sella troppo bassa.", "Spalle e collo tesi.", "Resistenza troppo alta all'inizio."]),
        "row_erg": g(
            ["Spingi con le gambe, poi inclina il busto, infine tira con le braccia.",
             "Ritorna nell'ordine opposto: braccia, busto, gambe.",
             "Mantieni un ritmo regolare."],
            ["Tirare con le braccia prima delle gambe.", "Schiena arrotondata.", "Ritorno troppo veloce."]),
        "jump_rope": g(
            ["Gomiti vicini ai fianchi, ruota la corda con i polsi.",
             "Salta poco, appena quanto basta per far passare la corda.",
             "Atterra sulla parte anteriore del piede."],
            ["Saltare troppo in alto.", "Muovere tutto il braccio.", "Atterrare sui talloni."]),
    ]
}

/// Loads the bundled demonstration photos (start and end position) for an exercise.
enum ExerciseMedia {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(_ key: String, index: Int) -> UIImage? {
        let name = "\(key)_\(index)"
        if let hit = cache.object(forKey: name as NSString) { return hit }
        guard let url = Bundle.main.url(forResource: name, withExtension: "jpg"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: name as NSString)
        return image
    }

    static func hasPhotos(_ key: String) -> Bool { image(key, index: 0) != nil }
}
