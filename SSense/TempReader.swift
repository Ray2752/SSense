import Foundation
import CoreFoundation
import os

// MARK: - Bindings privados
@_silgen_name("IOHIDEventSystemClientCreate")
internal nonisolated func IOHIDEventSystemClientCreate(_ alloc: CFAllocator?) -> AnyObject?

@_silgen_name("IOHIDEventSystemClientSetMatching")
internal nonisolated func IOHIDEventSystemClientSetMatching(_ client: AnyObject?, _ matching: CFDictionary?) -> Void

@_silgen_name("IOHIDEventSystemClientCopyServices")
internal nonisolated func IOHIDEventSystemClientCopyServices(_ client: AnyObject?) -> CFArray?

@_silgen_name("IOHIDServiceClientCopyEvent")
internal nonisolated func IOHIDServiceClientCopyEvent(_ service: AnyObject?, _ eventType: CFIndex, _ flags: Int32) -> AnyObject?

@_silgen_name("IOHIDEventGetFloatValue")
internal nonisolated func IOHIDEventGetFloatValue(_ event: AnyObject?, _ field: Int64) -> Double

// MARK: - Cache de índices útiles
private final class HIDCache: @unchecked Sendable {
    private nonisolated(unsafe) var indices: [Int]? = nil
    private let lock = OSAllocatedUnfairLock()

    nonisolated func getIndices() -> [Int]? {
        lock.withLock { indices }
    }

    nonisolated func setIndices(_ nuevos: [Int]) {
        lock.withLock { indices = nuevos }
    }
}

nonisolated private let hidCache = HIDCache()

// MARK: - Lectura
nonisolated func leerTemperaturaChipReal() -> Double? {
    let tempEventType: CFIndex = 15
    let tempField: Int64       = 983040

    guard let client = IOHIDEventSystemClientCreate(kCFAllocatorDefault) else { return nil }
    let criteria: [String: Any] = [
        "PrimaryUsagePage": Int32(0xFF00),
        "PrimaryUsage":     Int32(0x05)
    ]
    IOHIDEventSystemClientSetMatching(client, criteria as CFDictionary)
    guard let todos = IOHIDEventSystemClientCopyServices(client) as? [AnyObject] else { return nil }

    // Primera vez: descubrir índices útiles
    if hidCache.getIndices() == nil {
        var descubiertos: [Int] = []
        for (i, servicio) in todos.enumerated() {
            if let event = IOHIDServiceClientCopyEvent(servicio, tempEventType, 0) {
                let t = IOHIDEventGetFloatValue(event, tempField)
                if (10.0..<150.0).contains(t) {
                    descubiertos.append(i)
                }
            }
        }
        hidCache.setIndices(descubiertos)
        guard !descubiertos.isEmpty else { return nil }
        let lecturas = descubiertos.compactMap { i -> Double? in
            guard i < todos.count,
                  let event = IOHIDServiceClientCopyEvent(todos[i], tempEventType, 0) else { return nil }
            return IOHIDEventGetFloatValue(event, tempField)
        }
        return lecturas.reduce(0, +) / Double(lecturas.count)
    }

    // Llamadas siguientes: solo leer índices conocidos
    guard let utiles = hidCache.getIndices(), !utiles.isEmpty else { return nil }
    let lecturas = utiles.compactMap { i -> Double? in
        guard i < todos.count,
              let event = IOHIDServiceClientCopyEvent(todos[i], tempEventType, 0) else { return nil }
        let t = IOHIDEventGetFloatValue(event, tempField)
        return (10.0..<150.0).contains(t) ? t : nil
    }

    guard !lecturas.isEmpty else { return nil }
    return lecturas.reduce(0, +) / Double(lecturas.count)
}
