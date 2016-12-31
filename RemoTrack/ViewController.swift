//
//  ViewController.swift
//  RemoTrack
//
//  Created by Ahmed Shokry on 12/22/16.
//  Copyright © 2016 Shockry. All rights reserved.
//

import UIKit
import CoreBluetooth
import CoreMotion
import AudioToolbox

class ViewController: UIViewController, CBPeripheralManagerDelegate {

    //MARK: Properties
    @IBOutlet weak var helpText: UILabel!
    @IBOutlet weak var actionButton: UIButton!
    @IBOutlet weak var replayButton: UIButton!
    
    var player = Player(score: 0)
    
    
    //MARK: Bluetooth setup
    var peripheralManager: CBPeripheralManager!
    
    let accelerometerServiceUUID = CBUUID(string: "4431E162-161E-4DFD-9E90-69872DDA137D")

    let tiltAngleCharacteristicUUID = CBUUID(string: "FD0A7B0B-629F-4179-B2DC-7EF53BD4FE8B")
    let tiltAngleProperties: CBCharacteristicProperties = [.notify]
    let tiltAnglePermissions: CBAttributePermissions = []
    
    let bestScoreCharacteristicUUID = CBUUID(string: "CB6EEDE9-6AA5-4253-8629-31C53BC246CD")
    let bestScoreProperties: CBCharacteristicProperties = [.read, .write]
    let bestScorePermissions: CBAttributePermissions = [.readable, .writeable]
    
    let replayPressedCharacteristicUUID = CBUUID(string: "941E4433-FAE2-4EF4-AEEC-3866FF4C4BF3")
    let replayPressedProperties: CBCharacteristicProperties = [.notify]
    let replayPressedPermissions: CBAttributePermissions = []
    
    
    var tiltAngleCharacteristic: CBMutableCharacteristic!
    
    var bestScoreCharacteristic: CBMutableCharacteristic!
    
    var replayPressedCharacteristic: CBMutableCharacteristic!
    
    //Flag for action button tap
    var buttonDown: UInt8 = 0
    
    //MARK: Sensor setup
    var motionManager: CMMotionManager!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Bluetooth
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        
        
        // Initially, the characteristics are set to nil and changed later by reading sensor data
        tiltAngleCharacteristic = CBMutableCharacteristic(
            type: tiltAngleCharacteristicUUID,
            properties: tiltAngleProperties,
            value: nil,
            permissions: tiltAnglePermissions)
        
        bestScoreCharacteristic = CBMutableCharacteristic(
            type: bestScoreCharacteristicUUID,
            properties: bestScoreProperties,
            value: nil,
            permissions: bestScorePermissions)
        
        replayPressedCharacteristic = CBMutableCharacteristic(
            type: replayPressedCharacteristicUUID,
            properties: replayPressedProperties,
            value: nil,
            permissions: replayPressedPermissions)
        
        
        // Sensors
        motionManager = CMMotionManager()
        motionManager.deviceMotionUpdateInterval = 1.0/60.0
        
        
        // Player
        // If there is a stored player, use it
        if let playerObj = self.loadScore() {
            self.player = playerObj
        }
    }


    //MARK: Core Bluetooth methods
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {

        if peripheral.state == CBManagerState.poweredOn {
            let accelerometerService = CBMutableService(type: accelerometerServiceUUID, primary: true)
            accelerometerService.characteristics = [tiltAngleCharacteristic, bestScoreCharacteristic,
                                                    replayPressedCharacteristic]
            
            peripheralManager.add(accelerometerService)
            
            startAdvertising()
        } else {
            //TODO: make something about it 🙄
            //print (peripheral.state)
        }
    }


    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService,
                           error: Error?) {

        if error != nil {
            helpText.text = "Error setting up the service!"
            return
        }
    }


    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {

        if error != nil {
            helpText.text = "Error publishing the service!"
            return
        }

        helpText.text = "Ready to connect.."
    }

    
    func peripheralManager(_ peripheral: CBPeripheralManager,
                            central: CBCentral,
                            didSubscribeTo characteristic: CBCharacteristic) {
        
        if characteristic.uuid.isEqual(tiltAngleCharacteristic.uuid) {
            actionButton.isEnabled = true
            helpText.text = "Connected"
            startSendingTiltAngles()
            stopAdvertising()
        }
    }
    
    
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didUnsubscribeFrom characteristic: CBCharacteristic) {
        
        if characteristic.uuid.isEqual(tiltAngleCharacteristic.uuid) {
            actionButton.isEnabled = false
            helpText.text = "Game Disconnected"
            startAdvertising()
        }
    }
    
    
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didReceiveRead request: CBATTRequest){
        
        if request.characteristic.uuid.isEqual(bestScoreCharacteristic.uuid) {
            if bestScoreCharacteristic.value == nil {
                var playerScore = player.bestScore
                
                let payload = withUnsafePointer(to: &playerScore) {
                    Data(bytes: $0, count: MemoryLayout.size(ofValue: playerScore))
                }
                request.value = payload
                bestScoreCharacteristic.value = payload
            } else {
                request.value = bestScoreCharacteristic.value
            }

            peripheralManager.respond(
                to: request,
                withResult: .success)
        }
    }
    
    
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didReceiveWrite requests: [CBATTRequest]){
        
        for request in requests
        {
            if request.characteristic.uuid.isEqual(bestScoreCharacteristic.uuid)
            {
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                
                let requestScore = getScoreFromData(data: request.value)
                let currentScore = getScoreFromData(data: bestScoreCharacteristic.value)
                
                if requestScore > currentScore {
                    bestScoreCharacteristic.value = request.value
                    player.bestScore = requestScore
                    self.savePlayer()
                }
                
                
            }
        }
        
        peripheralManager.respond(to: requests[0], withResult: .success)
        cleanupForGameOver()
    }
    
    
    func startAdvertising() {
        
        //This is the name that will appear on the pairing menu of the browser
        let advertisementData = [CBAdvertisementDataLocalNameKey: "RemoTrack Remote"]
        
        peripheralManager.startAdvertising(advertisementData)
    }

    
    func stopAdvertising() {
        
        peripheralManager.stopAdvertising()
    }
    
    
    func startSendingTiltAngles() {
        
        motionManager.startDeviceMotionUpdates(to: OperationQueue.main) {
            (data: CMDeviceMotion?, error: Error?) in
            if let gravity = data?.gravity {
                // Getting the rotation angle and correct it to suit the landscape-right
                var rotation = (atan2(gravity.x, gravity.y) * -1) - (M_PI/2)
                
                var payload = Data([self.buttonDown])
                
                // Convert it into a byte array to send over Bluetooth
                let angle = withUnsafePointer(to: &rotation) {
                    Data(bytes: $0, count: MemoryLayout.size(ofValue: rotation))
                }
                
                payload.append(angle)

                self.peripheralManager.updateValue(
                    payload,
                    for: self.tiltAngleCharacteristic,
                    onSubscribedCentrals: nil)
            }
        }
    }
    
    
    func stopSendingTiltAngles() {
        
        motionManager.stopDeviceMotionUpdates()
    }
    
    //MARK: Private methods
    private func savePlayer() {
        NSKeyedArchiver.archiveRootObject(player, toFile: Player.ArchiveURL.path)
        
    }
    
    
    private func loadScore() -> Player? {
        return NSKeyedUnarchiver.unarchiveObject(withFile: Player.ArchiveURL.path) as? Player
    }
    
    
    private func getScoreFromData(data: Data?) -> UInt32 {
        
        if data == nil {
            return 0
        }
        
        // I guess there must be a better way of doing this.
        
        // Anyway, this reserves a 4 byte area in memory
        var val: UInt32 = 0
        
        // Make an UnsafeMutableBufferPointer to that area
        let valBuffer = UnsafeMutableBufferPointer(start: &val, count: MemoryLayout.size(ofValue: val))
        
        // Copy the value from the write request to that 4 byte area
        // so that it now contains the value from the request
        _ = data?.copyBytes(to: valBuffer, from: 0..<4)
        
        return val
    }
    
    
    private func cleanupForGameOver() {
        
        stopSendingTiltAngles()
        actionButton.isEnabled = false
        replayButton.isHidden = false
    }
    
    
    private func prepareForReplay() {
        
        startSendingTiltAngles()
        actionButton.isEnabled = true
        replayButton.isHidden = true
    }
    
    
    //MARK: Actions
    @IBAction func sendData(_ sender: UIButton) {
        
        buttonDown = 1
    }
    
    @IBAction func stopSendingData(_ sender: UIButton) {
        
        buttonDown = 0
    }

    @IBAction func replay(_ sender: UIButton) {
        
        // Notify the browser to restart the game
        let payload = Data([1])
        
        self.peripheralManager.updateValue(
            payload,
            for: self.replayPressedCharacteristic,
            onSubscribedCentrals: nil)
        prepareForReplay()
    }
}

