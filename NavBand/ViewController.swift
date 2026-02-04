import UIKit
import WebKit
import CoreBluetooth

class ViewController: UIViewController, WKScriptMessageHandler, CBCentralManagerDelegate, CBPeripheralDelegate {

    var webView: WKWebView!
    var centralManager: CBCentralManager!
    var navBandPeripheral: CBPeripheral?
    var commandCharacteristic: CBCharacteristic?
    var isJSReady = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup WKWebView
        let contentController = WKUserContentController()
        contentController.add(self, name: "ble")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController

        webView = WKWebView(frame: self.view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(webView)

        if let indexURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "build") {
            print("✅ index.html found at: \(indexURL)")
            webView.loadFileURL(indexURL, allowingReadAccessTo: indexURL.deletingLastPathComponent())
        } else {
            print("❌ index.html not found in build/")
        }

        // Start Bluetooth
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "ble" else { return }

        if let command = message.body as? String {
            if command == "__ready__" {
                print("✅ JS is ready, enabling BLE status sync.")
                isJSReady = true
                updateBLEStatus("Initializing...")
                return
            }

            print("📡 JS → Native BLE command:", command)
            if let characteristic = commandCharacteristic, let peripheral = navBandPeripheral {
                let data = command.data(using: .utf8)!
                peripheral.writeValue(data, for: characteristic, type: .withResponse)
            } else {
                print("⚠️ BLE not ready yet")
            }
        }
    }

    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("✅ Bluetooth is ON, scanning...")
            updateBLEStatus("Scanning...")
            central.scanForPeripherals(withServices: [CBUUID(string: "12345678-1234-5678-1234-56789abcdef0")], options: nil)
        default:
            print("❌ Bluetooth unavailable: \(central.state.rawValue)")
            updateBLEStatus("Bluetooth Unavailable")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("🔍 Found device: \(peripheral.name ?? "Unknown")")
        navBandPeripheral = peripheral
        navBandPeripheral?.delegate = self
        central.stopScan()
        central.connect(peripheral, options: nil)
        updateBLEStatus("Connecting...")
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("🔗 Connected to NavBand")
        updateBLEStatus("Connected")
        peripheral.discoverServices([CBUUID(string: "12345678-1234-5678-1234-56789abcdef0")])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("🔌 Disconnected from NavBand")
        updateBLEStatus("Disconnected")
    }

    // MARK: - CBPeripheralDelegate
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("❌ Service discovery failed:", error.localizedDescription)
            return
        }

        for service in peripheral.services ?? [] {
            print("🧩 Found service:", service.uuid)
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("❌ Characteristic discovery failed:", error.localizedDescription)
            return
        }

        for characteristic in service.characteristics ?? [] {
            print("📡 Found characteristic:", characteristic.uuid)
            if characteristic.uuid == CBUUID(string: "abcdef01-1234-5678-1234-56789abcdef0") {
                commandCharacteristic = characteristic
                updateBLEStatus("Ready")
                print("✅ BLE Ready to receive commands.")
            }
        }
    }

    // MARK: - JS Bridge: Send BLE Status
    func updateBLEStatus(_ status: String) {
        guard isJSReady else {
            print("⚠️ JS not ready — skipping BLE status: \(status)")
            return
        }

        let js = "window.updateBLEStatus('" + status + "')"
        webView.evaluateJavaScript(js, completionHandler: { _, error in
            if let error = error {
                print("❌ Failed to send BLE status to JS:", error.localizedDescription)
            } else {
                print("📶 Sent BLE status to JS:", status)
            }
        })
    }
}

