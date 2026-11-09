import CoreBluetooth
import Combine
import Foundation

struct BluetoothCharacteristicInfo: Identifiable {
    let id = UUID()
    let service: CBUUID
    let characteristic: CBUUID
    let properties: CBCharacteristicProperties
}

final class ZeehoBluetooth: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var state = "未开始扫描"
    @Published var peripherals: [CBPeripheral] = []
    @Published var characteristics: [BluetoothCharacteristicInfo] = []
    private var central: CBCentralManager!
    private var connected: CBPeripheral?

    override init() { super.init(); central = CBCentralManager(delegate: self, queue: nil) }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        state = central.state == .poweredOn ? "蓝牙已就绪" : "蓝牙状态：\(central.state.rawValue)"
    }
    func scan() {
        guard central.state == .poweredOn else { state = "请先打开蓝牙"; return }
        peripherals.removeAll(); characteristics.removeAll(); state = "正在扫描 BLE 设备…"
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }
    func stop() { central.stopScan(); state = "扫描已停止" }
    func connect(_ peripheral: CBPeripheral) { stop(); connected = peripheral; peripheral.delegate = self; central.connect(peripheral); state = "正在连接…" }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if !peripherals.contains(where: { $0.identifier == peripheral.identifier }) { peripherals.append(peripheral) }
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) { state = "已连接，发现服务中…"; peripheral.discoverServices(nil) }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) { state = "连接失败：\(error?.localizedDescription ?? "未知错误")" }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error { state = "服务发现失败：\(error.localizedDescription)"; return }
        for service in peripheral.services ?? [] { peripheral.discoverCharacteristics(nil, for: service) }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error { state = "特征发现失败：\(error.localizedDescription)"; return }
        for characteristic in service.characteristics ?? [] {
            characteristics.append(BluetoothCharacteristicInfo(service: service.uuid, characteristic: characteristic.uuid, properties: characteristic.properties))
            if characteristic.properties.contains(.notify) { peripheral.setNotifyValue(true, for: characteristic) }
        }
        state = "已发现 \(characteristics.count) 个特征"
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error { state = "通知读取失败：\(error.localizedDescription)"; return }
        state = "收到 \(characteristic.value?.count ?? 0) 字节通知：\(characteristic.uuid.uuidString)"
    }
}
