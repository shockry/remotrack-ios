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

class ViewController: UIViewController, CBPeripheralManagerDelegate {

    //MARK: Properties
    @IBOutlet weak var helpText: UILabel!
    @IBOutlet weak var actionButton: UIButton!
    
    //MARK: Bluetooth setup
    var peripheralManager: CBPeripheralManager!
    
    let accelerometerServiceUUID = CBUUID(string: "4431E162-161E-4DFD-9E90-69872DDA137D")

    let tiltAngleCharacteristicUUID = CBUUID(string: "FD0A7B0B-629F-4179-B2DC-7EF53BD4FE8B")
    let tiltAngleProperties: CBCharacteristicProperties = [.notify]
    let tiltAnglePermissions: CBAttributePermissions = []
    
    var tiltAngleCharacteristic: CBMutableCharacteristic!
    
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
        
        // Sensors
        motionManager = CMMotionManager()
        motionManager.deviceMotionUpdateInterval = 1.0/60.0
    }


    //MARK: Core Bluetooth methods
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {

        if peripheral.state == CBManagerState.poweredOn {
            let accelerometerService = CBMutableService(type: accelerometerServiceUUID, primary: true)
            accelerometerService.characteristics = [tiltAngleCharacteristic]
            
            peripheralManager.add(accelerometerService)
            
            startAdvertising()
        } else {
            //DOTO: make something about it 🙄
            print (peripheral.state)
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
        
        actionButton.isEnabled = true
        helpText.text = "Connected"
        stopAdvertising()
    }
    
    
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didUnsubscribeFrom characteristic: CBCharacteristic) {
        
        actionButton.isEnabled = false
        helpText.text = "Game Disconnected"
        startAdvertising()
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
                
                // Convert it into a byte array to send over Bluetooth
                let payload =  Data(bytes: &rotation, count: MemoryLayout.size(ofValue: rotation))

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
    
    
    //MARK: Actions
    @IBAction func sendData(_ sender: UIButton) {
        
        startSendingTiltAngles()
    }
    
    @IBAction func stopSendingData(_ sender: UIButton) {
        
        stopSendingTiltAngles()
    }

}

