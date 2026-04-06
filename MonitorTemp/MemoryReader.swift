import Foundation
import Darwin

// MARK: - Modelos

struct InfoMemoria {
    var ramUsadaGB: Double
    var ramTotalGB: Double
    var swapUsadoGB: Double
    var appMemoriaGB: Double
    var memoriaAlambreGB: Double
    var memoriaComprimidaGB: Double
    var archivosEnCacheGB: Double
}

// MARK: - Memoria del sistema

nonisolated func leerMemoriaSistema() -> InfoMemoria? {
    let ramTotalBytes = ProcessInfo.processInfo.physicalMemory
    let ramTotalGB    = Double(ramTotalBytes) / 1_073_741_824.0

    var stats = vm_statistics64_data_t()
    var count = mach_msg_type_number_t(
        MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
    )

    let resultado = withUnsafeMutablePointer(to: &stats) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
        }
    }

    guard resultado == KERN_SUCCESS else { return nil }

    let paginaBytes   = UInt64(vm_kernel_page_size)
    let libres        = UInt64(stats.free_count - stats.speculative_count)
    let archivosCache = UInt64(stats.external_page_count)

    let descuento     = (libres + archivosCache) * paginaBytes
    let ramUsadaBytes = descuento < ramTotalBytes ? ramTotalBytes - descuento : 0
    let ramUsadaGB    = Double(ramUsadaBytes) / 1_073_741_824.0

    let toGB = { (paginas: UInt32) in Double(paginas) * Double(paginaBytes) / 1_073_741_824.0 }

    let appMemoriaGB      = max(toGB(stats.internal_page_count - stats.purgeable_count), 0.0)
    let alambreGB         = toGB(stats.wire_count)
    let comprimidaGB      = toGB(stats.compressor_page_count)
    let archivosEnCacheGB = toGB(stats.external_page_count)

    var mib      = [CTL_VM, VM_SWAPUSAGE]
    var swap     = xsw_usage()
    var swapSize = MemoryLayout<xsw_usage>.size
    var swapUsadoGB = 0.0

    if sysctl(&mib, u_int(mib.count), &swap, &swapSize, nil, 0) == 0 {
        swapUsadoGB = Double(swap.xsu_used) / 1_073_741_824.0
    }

    return InfoMemoria(
        ramUsadaGB:          min(max(ramUsadaGB, 0.0), ramTotalGB),
        ramTotalGB:          ramTotalGB,
        swapUsadoGB:         swapUsadoGB,
        appMemoriaGB:        appMemoriaGB,
        memoriaAlambreGB:    alambreGB,
        memoriaComprimidaGB: comprimidaGB,
        archivosEnCacheGB:   archivosEnCacheGB
    )
}

// MARK: - Memoria de la app actual

nonisolated func leerMemoriaApp() -> Double? {
    var info  = mach_task_basic_info()
    var count = mach_msg_type_number_t(
        MemoryLayout<mach_task_basic_info_data_t>.size / MemoryLayout<natural_t>.size
    )

    let kerr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }

    guard kerr == KERN_SUCCESS else { return nil }
    return Double(info.resident_size) / 1_048_576.0
}

// MARK: - Impresión

nonisolated func imprimirEstadoMemoria() {
    guard leerMemoriaSistema() != nil else {
        print("Error: no se pudo leer la memoria del sistema.")
        return
    }
}
