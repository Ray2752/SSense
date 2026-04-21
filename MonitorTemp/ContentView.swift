import Foundation
import Combine

@MainActor
class MonitorTemperatura: ObservableObject {

    // MARK: - Public State
    @Published var temperaturaActual: String   = "-- °C"
    @Published var temperaturaNumerica: Double = 0.0
    @Published var errorTemperatura: Bool      = false

    @Published var textoRAM: String          = "-- GB"
    @Published var textoMemoriaApp: String   = "-- MB"
    @Published var textoSwap: String         = "-- GB"
    @Published var alertaSwap: Bool          = false
    @Published var swapUsadoGB: Double       = 0.0
    @Published var ramUsadaGB: Double        = 0.0
    @Published var ramTotalGB: Double        = 0.0
    @Published var memoriaAppUsadaMB: Double = 0.0

    // MARK: - Private
    private var cancellable: AnyCancellable?
    private var intervaloActual: TimeInterval = 2.0
    private var tareaEnCurso: Task<Void, Never>? = nil

    // MARK: - Init
    init() {
        iniciarMonitoreo() }

    // MARK: - Monitoring
    func iniciarMonitoreo() {
        leerSensores()
        programarTimer()
    }

    func configurarIntervalo(segundos: TimeInterval) {
        let nuevo = max(0.5, segundos)
        guard abs(nuevo - intervaloActual) > 0.001 else { return }
        intervaloActual = nuevo
        programarTimer()
    }

    func refrescarAhora() { leerSensores() }

    private func programarTimer() {
        cancellable?.cancel()
        cancellable = Timer
            .publish(every: intervaloActual, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.leerSensores() }
    }

    // MARK: - Core Logic
    private func leerSensores() {
        tareaEnCurso?.cancel()

        tareaEnCurso = Task.detached(priority: .utility) { [weak self] in
            // Temperatura y memoria se leen en paralelo, fuera del MainActor
            async let temp    = Task.detached(priority: .utility) { leerTemperaturaChipReal() }.value
            async let memoria = Task.detached(priority: .utility) { leerMemoriaSistema() }.value
            async let app     = Task.detached(priority: .utility) { leerMemoriaApp() }.value

            let (t, m, a) = await (temp, memoria, app)

            guard !Task.isCancelled else { return }

            // Publicar resultados de vuelta en el MainActor
            await self?.aplicarTemperatura(t)
            await self?.aplicarMemoria(m, app: a)
        }
    }

    // MARK: - Aplicar resultados (MainActor garantizado por la clase)
    private func aplicarTemperatura(_ temp: Double?) {
        if let temp {
            temperaturaNumerica = temp
            temperaturaActual   = String(format: "%.1f °C", temp)
            errorTemperatura    = false
        } else {
            if temperaturaNumerica == 0.0 { temperaturaActual = "-- °C" }
            errorTemperatura = true
        }
    }

    private func aplicarMemoria(_ m: InfoMemoria?, app: Double?) {
        guard let m else { return }

        textoRAM    = String(format: "%.2f / %.0f GB", m.ramUsadaGB, m.ramTotalGB)
        textoSwap   = String(format: "%.2f GB", m.swapUsadoGB)
        alertaSwap  = m.swapUsadoGB > 2.0
        swapUsadoGB = m.swapUsadoGB
        ramUsadaGB  = m.ramUsadaGB
        ramTotalGB  = m.ramTotalGB

        if let usadaMB = app {
            memoriaAppUsadaMB = usadaMB
            textoMemoriaApp   = String(format: "%.0f MB", usadaMB)
        } else {
            memoriaAppUsadaMB = 0.0
            textoMemoriaApp   = "-- MB"
        }
    }

    // MARK: - Cleanup
    deinit {
        cancellable?.cancel()
        tareaEnCurso?.cancel()
    }
}


