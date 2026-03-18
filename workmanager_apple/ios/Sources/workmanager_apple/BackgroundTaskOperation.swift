//
//  BackgroundTaskOperation.swift
//  workmanager
//
//  Created by Sebastian Roth on 10/06/2021.
//

import Foundation

#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#else
#error("Unsupported platform.")
#endif

class BackgroundTaskOperation: Operation, @unchecked Sendable {

    private let identifier: String
    private let flutterPluginRegistrantCallback: FlutterPluginRegistrantCallback?
    private let inputData: [String: Any]?
    private let backgroundMode: BackgroundMode
    private let stateQueue = DispatchQueue(label: "dev.fluttercommunity.workmanager.operation")
    private var worker: BackgroundWorker?
    private var pendingExpiration = false

    init(_ identifier: String,
         inputData: [String: Any]?,
         flutterPluginRegistrantCallback: FlutterPluginRegistrantCallback?,
         backgroundMode: BackgroundMode) {
        self.identifier = identifier
        self.inputData = inputData
        self.flutterPluginRegistrantCallback = flutterPluginRegistrantCallback
        self.backgroundMode = backgroundMode
    }

    func handleExpiration() {
        stateQueue.sync {
            if let worker {
                worker.handleExpiration()
            } else {
                pendingExpiration = true
            }
        }
    }

    override func main() {
        let semaphore = DispatchSemaphore(value: 0)
        let worker = BackgroundWorker(mode: self.backgroundMode,
                                      inputData: self.inputData,
                                      flutterPluginRegistrantCallback: self.flutterPluginRegistrantCallback)
        stateQueue.sync {
            self.worker = worker
            if pendingExpiration {
                worker.handleExpiration()
                pendingExpiration = false
            }
        }
        DispatchQueue.main.async {
            worker.performBackgroundRequest { _ in
                semaphore.signal()
            }
        }

        semaphore.wait()
    }
}
