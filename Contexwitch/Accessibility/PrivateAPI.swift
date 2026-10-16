//
//  PrivateAPI.swift
//  Contexwitch
//
//  Private HIServices / SkyLight symbols, resolved at runtime so a missing
//  symbol degrades gracefully instead of failing to launch. These are the
//  same calls used by other macOS window switchers (e.g. AltTab).
//

import ApplicationServices
import Darwin

nonisolated enum PrivateAPI {
    private typealias AXGetWindowFn = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    private typealias AXCreateWithRemoteTokenFn = @convention(c) (CFData) -> Unmanaged<AXUIElement>?
    private typealias GetProcessForPIDFn = @convention(c) (pid_t, UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus
    private typealias SetFrontProcessFn = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, CGWindowID, UInt32) -> CGError
    private typealias PostEventRecordFn = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UnsafeMutablePointer<UInt8>) -> CGError

    private static let defaultHandle = UnsafeMutableRawPointer(bitPattern: -2) // RTLD_DEFAULT
    nonisolated(unsafe) private static let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)

    private static func symbol<T>(_ name: String, in handle: UnsafeMutableRawPointer?) -> T? {
        guard let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }

    private static let axGetWindow: AXGetWindowFn? = symbol("_AXUIElementGetWindow", in: defaultHandle)
    private static let axCreateWithRemoteToken: AXCreateWithRemoteTokenFn? = symbol("_AXUIElementCreateWithRemoteToken", in: defaultHandle)
    private static let getProcessForPID: GetProcessForPIDFn? = symbol("GetProcessForPID", in: defaultHandle)
    private static let setFrontProcess: SetFrontProcessFn? = symbol("_SLPSSetFrontProcessWithOptions", in: skyLight)
    private static let postEventRecord: PostEventRecordFn? = symbol("SLPSPostEventRecordTo", in: skyLight)

    /// The CoreGraphics window number backing an AX window element.
    static func windowID(of element: AXUIElement) -> CGWindowID? {
        guard let axGetWindow else { return nil }
        var id: CGWindowID = 0
        guard axGetWindow(element, &id) == .success, id != 0 else { return nil }
        return id
    }

    /// `kAXWindowsAttribute` only reports windows on the current Space. Window
    /// elements on other Spaces can still be reached by brute-forcing their
    /// remote tokens. Stops once every wanted window is found or the deadline passes;
    /// `isExhaustive` is true only if every token was checked.
    static func windowsFromRemoteTokens(
        pid: pid_t, wanted: Set<CGWindowID>, timeout: TimeInterval = 0.25
    ) -> (windows: [AXUIElement], isExhaustive: Bool) {
        guard let axCreateWithRemoteToken else { return ([], false) }
        var token = Data(count: 20)
        token.replaceSubrange(0..<4, with: withUnsafeBytes(of: pid) { Data($0) })
        token.replaceSubrange(4..<8, with: withUnsafeBytes(of: Int32(0)) { Data($0) })
        token.replaceSubrange(8..<12, with: withUnsafeBytes(of: Int32(0x636f_636f)) { Data($0) })

        let deadline = Date().addingTimeInterval(timeout)
        var remaining = wanted
        var found: [AXUIElement] = []
        for elementID: UInt64 in 0..<1000 {
            if remaining.isEmpty { break }
            if Date() > deadline { return (found, false) }
            token.replaceSubrange(12..<20, with: withUnsafeBytes(of: elementID) { Data($0) })
            guard let element = axCreateWithRemoteToken(token as CFData)?.takeRetainedValue(),
                  let id = windowID(of: element), remaining.contains(id) else { continue }
            remaining.remove(id)
            found.append(element)
        }
        return (found, true)
    }

    /// Brings a specific window forward, including windows on other Spaces and
    /// fullscreen windows. Returns false if the private API is unavailable.
    static func focus(pid: pid_t, windowID: CGWindowID) -> Bool {
        guard let getProcessForPID, let setFrontProcess, let postEventRecord else { return false }
        var psn = ProcessSerialNumber()
        guard getProcessForPID(pid, &psn) == noErr else { return false }
        guard setFrontProcess(&psn, windowID, 0x200 /* userGenerated */) == .success else { return false }

        // Synthesised "make key window" event records.
        var bytes = [UInt8](repeating: 0, count: 0xf8)
        bytes[0x04] = 0xf8
        bytes[0x3a] = 0x10
        withUnsafeBytes(of: windowID) { bytes.replaceSubrange(0x3c..<0x40, with: $0) }
        for index in 0x20..<0x30 { bytes[index] = 0xff }
        bytes[0x08] = 0x01
        _ = postEventRecord(&psn, &bytes)
        bytes[0x08] = 0x02
        _ = postEventRecord(&psn, &bytes)
        return true
    }
}
