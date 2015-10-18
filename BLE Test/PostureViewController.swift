
//  PostureViewController.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 9/30/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import Foundation
import UIKit
import Dispatch


protocol PostureViewControllerDelegate: HelpViewControllerDelegate {
    func sendData(newData:NSData)
}

// Data Type Definitions
enum PostureStatus:Int {
    case OK
    case Left
    case Right
    case Forward
    case Back
}

public struct Vector {
    var x:Int
    var y:Int
    var z:Int
}

public struct SensorData {
    var accel:Vector
    var mag:Vector
    var gyro:Vector
}

enum ActuatorType {
    case Buzzer
}

public let gyroTrigger = 400 // sense data beyond which we sense a lean
public let triggerCount = 3 // number of times in a row that a trigger has to occur to sound an alarm

public struct ActuatorCommand {
    var type:ActuatorType?
    var id:Int? // 0, 1, 2, 3, etc
}

class PostureViewController: UIViewController {
    var delegate:PostureViewControllerDelegate?
    @IBOutlet var helpViewController:HelpViewController!
    
    convenience init(aDelegate:PostureViewControllerDelegate?){
        self.init(nibName: "PostureViewController" as String, bundle: NSBundle.mainBundle())
        
        self.delegate = aDelegate
        self.title = "Posture"
    }
    
    var ax = [Int](count: triggerCount, repeatedValue: 0)
    var az = [Int](count: triggerCount, repeatedValue: 0)
    var sumX=0, sumZ=0
    
    
    override func viewDidLoad(){
        
        //setup help view
        self.helpViewController.title = "Help"
        self.helpViewController.delegate = delegate
        
    }
    
    func transmitTX(tx:NSString){
        // 'tx' is the bluetooth command transmission as a string
        
        let data = NSData(bytes: tx.UTF8String, length: tx.length)
        delegate?.sendData(data)
        
    }
    
    func receiveRX(rx:NSString) {
        // 'rx' is the bluetooth data transmission as a string
        NSLog("Transmission: %@", rx);
    }
    
    func parse(rx:NSString)->SensorData? {
        // typical input string: !A0-1037.00@-14939.00@6112.00!G0194.00@-116.00@-266.00!M0870.00@-3623.00@-1348.00
        // use it to fill a sensorData structure
        // if an error, return nil structure
        var xyz: [String]
        var sensorData = SensorData(
            accel: Vector(x: 0,y: 0,z: 0),
            mag: Vector(x: 0,y: 0,z: 0),
            gyro: Vector(x: 0,y: 0,z: 0))
        var vector = rx.componentsSeparatedByString("!") // split into vectors
        if vector.count != 4 || vector[0] != ""  { return nil } // first character is supposed to be "!" so first split should be empty string
        // then there should be one vector for each of array, gyro and mag so a total of 4 entries
        for i in 1...3 {
            var prefix: String
            switch i {
            case 1:
                prefix="A0"
            case 2:
                prefix="G0"
            default:
                prefix="M0"
            }
            
            if !vector[i].hasPrefix(prefix) {return nil}  // next two chars are supposed to be prefix
            vector[i].removeAtIndex(vector[i].startIndex) // remove prefix i.e. first two characters
            vector[i].removeAtIndex(vector[i].startIndex)
            
            xyz = vector[i].componentsSeparatedByString("@") // split into x, y and z values
            if xyz.count != 3 { return nil } // should split into exactly 3 strings
            for k in 0...2 {  // strip trailing ".00" before converting to Int
                xyz[k] = xyz[k].stringByReplacingOccurrencesOfString(".00", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
            }
            switch i {
            case 1:
                if let j = Int(xyz[0]) { sensorData.accel.x = j } else { return nil }
                if let j = Int(xyz[1]) { sensorData.accel.y = j } else { return nil }
                if let j = Int(xyz[2]) { sensorData.accel.z = j } else { return nil }
            case 2:
                if let j = Int(xyz[0]) { sensorData.gyro.x = j } else { return nil }
                if let j = Int(xyz[1]) { sensorData.gyro.y = j } else { return nil }
                if let j = Int(xyz[2]) { sensorData.gyro.z = j } else { return nil }
            default:
                if let j = Int(xyz[0]) { sensorData.mag.x = j } else { return nil }
                if let j = Int(xyz[1]) { sensorData.mag.y = j } else { return nil }
                if let j = Int(xyz[2]) { sensorData.mag.z = j } else { return nil }
            }
        }
        return sensorData
    }
    
    func unParse(tx:Int)->NSString {
        if case 0...4 = tx {
            return "!B\(tx)@"
        }
        
        return ""
    }
    
    func calculatePostureStatus(sensorData:SensorData)->PostureStatus {
        var runningAvg: Int
        sumX -= ax[0] // ignore oldest gyro.x value
        for i in 0..<ax.count-1 {
            ax[i] = ax[i+1] // shunt older values back
        }
        ax[ax.count-1] = sensorData.gyro.x // introduce new value
        sumX += ax[ax.count-1] // new sum of last three values
        runningAvg = sumX/ax.count
        if runningAvg > gyroTrigger {return PostureStatus.Forward}
        else if runningAvg < -gyroTrigger {return PostureStatus.Back}
        
        sumZ -= az[0] // ignore oldest gyro.x value
        for i in 0..<az.count-1 {
            az[i] = az[i+1] // shunt older values back
        }
        az[az.count-1] = sensorData.gyro.z // introduce new value
        sumZ += az[az.count-1] // new sum of last three values
        runningAvg = sumZ/az.count
        if runningAvg > gyroTrigger {return PostureStatus.Left}
        else if runningAvg < -gyroTrigger {return PostureStatus.Right}
        
        return PostureStatus.OK
    }
    
    func didConnect() {
        // bluetooth connection is now established
    }
    
    func receiveData(rxData : NSData){
        
        if (isViewLoaded() && view.window != nil) {
            let rx = NSString(bytes: rxData.bytes, length: rxData.length, encoding: NSUTF8StringEncoding)
            receiveRX(rx!);
        }
        
    }
}





