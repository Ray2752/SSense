import SwiftUI

enum OpcionBarra: String, CaseIterable {
    case temperatura = "Temperatura"
    case ram  = "RAM"
    case app  = "App"
    case swap = "Swap"
}

@main
struct SSenseApp: App {
    @StateObject private var monitor = MonitorTemperatura()
    @AppStorage("opcionBarraMenu") private var opcionBarra: OpcionBarra = .temperatura
    @State private var menuAbierto: Bool = false

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 6) {
                encabezado

                indicador(
                    titulo: "Temperatura",
                    valor: monitor.errorTemperatura
                        ? "Sin lectura" : monitor.temperaturaActual,
                    icono: iconoTemp,
                    color: colorTemperatura,
                    progreso: progresoTemperatura,
                    subtitulo: monitor.errorTemperatura
                        ? "Sensor no disponible" : estadoResumen
                )

                indicador(
                    titulo: "RAM",
                    valor: monitor.textoRAM,
                    icono: "memorychip.fill",
                    color: .blue,
                    progreso: progresoRAM,
                    subtitulo: "Memoria en uso"
                )

                indicador(
                    titulo: "Esta app",
                    valor: monitor.textoMemoriaApp,
                    icono: "app.fill",
                    color: .mint,
                    progreso: progresoMemoriaApp,
                    subtitulo: "Proceso actual"
                )

                indicador(
                    titulo: "Swap",
                    valor: monitor.textoSwap,
                    icono: monitor.alertaSwap
                        ? "exclamationmark.triangle.fill"
                        : "arrow.up.arrow.down.square.fill",
                    color: colorSwap,
                    progreso: progresoSwap,
                    subtitulo: monitor.alertaSwap
                        ? "Revisa apps en segundo plano" : "Consumo estable"
                )

                Divider().padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Mostrar en la barra de menú:")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Picker("", selection: $opcionBarra) {
                        Text("Temp").tag(OpcionBarra.temperatura)
                        Text("RAM").tag(OpcionBarra.ram)
                        Text("App").tag(OpcionBarra.app)
                        Text("Swap").tag(OpcionBarra.swap)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .padding(.bottom, 2)

                Divider().padding(.vertical, 4)

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    HStack {
                        Image(systemName: "power")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Salir")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                        Spacer()
                        Text("⌘Q")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q")
            }
            .padding(16)
            .frame(width: 320)
            .background(Material.regular)
            .preferredColorScheme(.dark)
            .onAppear {
                menuAbierto = true
                monitor.refrescarAhora()
                actualizarFrecuencia()
            }
            .onDisappear {
                menuAbierto = false
                actualizarFrecuencia()
            }
            .onChange(of: opcionBarra) { _, _ in actualizarFrecuencia() }
            .onChange(of: menuAbierto) { _, _ in actualizarFrecuencia() }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: iconoPrincipal)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(colorEstado)
                    .font(.system(size: 13, weight: .semibold))
                Text(textoPrincipal)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.window)
    }

    // MARK: - Frecuencia adaptativa
    private func actualizarFrecuencia() {
        let intervalo: TimeInterval
        if menuAbierto {
            intervalo = 0.5
        } else if opcionBarra == .ram || opcionBarra == .app {
            intervalo = 1.0
        } else {
            intervalo = 2.0
        }
        monitor.configurarIntervalo(segundos: intervalo)
    }

    // MARK: - Encabezado
    private var encabezado: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [colorTemperatura.opacity(0.8),
                                 colorTemperatura.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 40, height: 40)
                Image(systemName: iconoTemp)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("SSense")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(estadoResumen)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(temperaturaCorta)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(colorTemperatura)
                Text("En vivo")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.2))
                    .foregroundStyle(.red)
                    .clipShape(Capsule())
            }
        }
        .padding(.bottom, 6)
    }

    // MARK: - Componente indicador
    private func indicador(
        titulo: String,
        valor: String,
        icono: String,
        color: Color,
        progreso: Double,
        subtitulo: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icono)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 20)
                Text(titulo)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Spacer()
                Text(valor)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 6)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(
                            width: geo.size.width * max(0, min(CGFloat(progreso), 1)),
                            height: 6
                        )
                }
            }
            .frame(height: 6)
            .padding(.vertical, 4)
            HStack {
                Text(subtitulo)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(progreso * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Computed properties
    var textoPrincipal: String {
        switch opcionBarra {
        case .temperatura: return temperaturaCorta
        case .ram:  return String(format: "%.2fG", monitor.ramUsadaGB)
        case .app:  return String(format: "%.0fM", monitor.memoriaAppUsadaMB)
        case .swap: return String(format: "%.1fG", monitor.swapUsadoGB)
        }
    }

    var iconoPrincipal: String {
        if monitor.alertaSwap { return "exclamationmark.triangle.fill" }
        switch opcionBarra {
        case .temperatura: return iconoTemp
        case .ram:  return "memorychip.fill"
        case .app:  return "app.fill"
        case .swap: return "arrow.up.arrow.down.square.fill"
        }
    }

    var temperaturaCorta: String {
        monitor.errorTemperatura ? "--°" : String(format: "%.1f°", monitor.temperaturaNumerica)
    }

    var progresoTemperatura: Double {
        max(0, min((monitor.temperaturaNumerica - 20.0) / 70.0, 1.0))
    }

    var progresoRAM: Double {
        guard monitor.ramTotalGB > 0 else { return 0 }
        return monitor.ramUsadaGB / monitor.ramTotalGB
    }

    var progresoMemoriaApp: Double {
        min(monitor.memoriaAppUsadaMB / 500.0, 1.0)
    }

    var progresoSwap: Double {
        min(monitor.swapUsadoGB / 4.0, 1.0)
    }

    var colorSwap: Color {
        monitor.alertaSwap ? .red : Color(nsColor: .systemPurple)
    }

    var colorEstado: Color {
        if monitor.alertaSwap { return .red }
        switch opcionBarra {
        case .temperatura: return colorTemperatura
        case .ram:  return .blue
        case .app:  return .mint
        case .swap: return colorSwap
        }
    }

    var colorTemperatura: Color {
        switch monitor.temperaturaNumerica {
        case 0..<50: return .green
        case 50..<70: return .orange
        default:      return .red
        }
    }

    var estadoResumen: String {
        if monitor.alertaSwap { return "Swap alto" }
        if monitor.errorTemperatura { return "Sensor no disponible" }
        switch monitor.temperaturaNumerica {
        case 0..<50: return "Sistema estable"
        case 50..<70: return "Carga media"
        default:      return "Temperatura elevada"
        }
    }

    var iconoTemp: String {
        switch monitor.temperaturaNumerica {
        case 0:       return "thermometer"
        case 0..<50:  return "thermometer.snowflake"
        case 50..<70: return "thermometer.medium"
        default:      return "flame.fill"
        }
    }
}


