
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
    var parseString = "", nextString = ""
    
    
    override func viewDidLoad(){
        
        //setup help view
        self.helpViewController.title = "Help"
        self.helpViewController.delegate = delegate
        
    }
    
    func transmitTX(tx:NSString){
        // 'tx' is the bluetooth command transmission as a string
        // from iPhone to Flora
        let data = NSData(bytes: tx.UTF8String, length: tx.length)
        delegate?.sendData(data)
        
    }
    
    func receiveRX(rx:NSString) {
        // 'rx' is the bluetooth data transmission as a string
        // from Flora to iPhone
        // This routine is called by iOS when Bluetooth data arrives
        //NSLog("Transmission: %@", rx);
        
        // Log of typical received data:
        //        2015-10-20 18:38:50.319 Adafruit Bluefruit LE Connect[224:13769] Transmission: !A0-1859.00@-5229.00
        //        2015-10-20 18:38:50.559 Adafruit Bluefruit LE Connect[224:13769] Transmission: @14471.00!G012.00@-2
        //        2015-10-20 18:38:50.799 Adafruit Bluefruit LE Connect[224:13769] Transmission: 6.00@-111.00!M0753.0
        //        2015-10-20 18:38:50.979 Adafruit Bluefruit LE Connect[224:13769] Transmission: 0@259.00@-4782.00
        //        2015-10-20 18:38:51.249 Adafruit Bluefruit LE Connect[224:13769] Transmission: !A0-1788.00@-5215.00
        //        2015-10-20 18:38:51.429 Adafruit Bluefruit LE Connect[224:13769] Transmission: @14437.00!G023.00@51
        //        2015-10-20 18:38:51.670 Adafruit Bluefruit LE Connect[224:13769] Transmission: .00@-109.00!M0740.00
        //        2015-10-20 18:38:51.849 Adafruit Bluefruit LE Connect[224:13769] Transmission: @274.00@-4791.00
        //        2015-10-20 18:38:52.089 Adafruit Bluefruit LE Connect[224:13769] Transmission: !A0-1814.00@-5173.00
        //        2015-10-20 18:38:52.329 Adafruit Bluefruit LE Connect[224:13769] Transmission: @14478.00!G036.00@70
        //        2015-10-20 18:38:52.539 Adafruit Bluefruit LE Connect[224:13769] Transmission: .00@-157.00!M0733.00
        //        2015-10-20 18:38:52.719 Adafruit Bluefruit LE Connect[224:13769] Transmission: @267.00@-4803.00
        
        var rxString = rx as String
        var rangeBangA0: Range<String.Index>?
        
        // if we had a fragment of string left over from last transmission, 
        // use it to start next parse string
        if !nextString.isEmpty {
            parseString = nextString
            nextString = ""
        }
        
        if rxString.hasPrefix("!A0") {
            parseString=rxString // if rx string begins with !A0, use it as start of parse string
        } else {
            // look for !A0 elsewhere in string
            rangeBangA0 = rxString.rangeOfString("!A0")
            if let foundBangA0 = rangeBangA0 {
                // rxString doesn't begin with !A0 but has it later on
                if parseString.isEmpty {
                    // ignore part of string leading up to !A0, and start parse string from here
                    parseString = rxString.substringFromIndex(foundBangA0.startIndex)
                } else {
                    // if already got a string starting with !A0,
                    // so append rx string up until second !A0
                    parseString += rxString.substringToIndex(foundBangA0.startIndex)
                    // and save rest of rx string to start new parse string next time
                    nextString = rxString.substringFromIndex(foundBangA0.startIndex)
                }
            } else {
                // no !A0 found, so
                if !parseString.isEmpty {
                    // append it if parse string already started
                    parseString += rxString
                } // don't start parse string until a !A0 is found
            }
        }
        
        // Check to see if we've got a full string ready for parsing
        if parseString.rangeOfString("!A0") == nil ||
            parseString.rangeOfString("!G0") == nil ||
            parseString.rangeOfString("!M0") == nil ||
            parseString.componentsSeparatedByString("@").count < 7 ||
            !parseString.hasSuffix(".00") {
                if parseString.characters.count > 100 {
                    // String shouldn't be longer than 100; log error, empty string and try again
                    NSLog("parseString too long: \(parseString.characters.count)")
                    parseString = ""
                }
                return  // receive more of transmission before parsing
        }
        // receive more of transmission before parsing
        
        if let sensorData = parse(parseString) {
            let posture = calculatePostureStatus(sensorData)
            switch posture {
            case PostureStatus.Left:
                transmitTX("!B0@") ; NSLog("Left")
            case PostureStatus.Forward:
                transmitTX("!B1@") ; NSLog("Forward")
            case PostureStatus.Right:
                transmitTX("!B2@") ; NSLog("Right")
            case PostureStatus.Back:
                transmitTX("!B3@") ; NSLog("Back")
            default:
                transmitTX("!B4@") ; NSLog("OK")
            }
        } else {
            NSLog("Failed parse: %@", parseString);
            // better luck next time
        }
        
        parseString = ""
    }
    
    func parse(rx:String)->SensorData? {
        // typical input string: !A0-1037.00@-14939.00@6112.00!G0194.00@-116.00@-266.00!M0870.00@-3623.00@-1348.00
        // use it to fill a sensorData structure
        // if an error, return nil structure
        var xyz: [String]
        var sensorData = SensorData(
            accel: Vector(x: 0,y: 0,z: 0),
            mag: Vector(x: 0,y: 0,z: 0),
            gyro: Vector(x: 0,y: 0,z: 0))
        var vector = rx.componentsSeparatedByString("!") // split into vector strings
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
        var movingAvg: Int
        
        sumX -= ax[0] // ignore oldest gyro.x value
        for i in 0..<ax.count-1 {
            ax[i] = ax[i+1] // shunt older values back
        }
        ax[ax.count-1] = sensorData.gyro.x // introduce new value
        sumX += ax[ax.count-1] // new sum of last three values
        movingAvg = sumX/ax.count
        
        if movingAvg > gyroTrigger {return PostureStatus.Forward}
        else if movingAvg < -gyroTrigger {return PostureStatus.Back}
        
        sumZ -= az[0] // ignore oldest gyro.x value
        for i in 0..<az.count-1 {
            az[i] = az[i+1] // shunt older values back
        }
        az[az.count-1] = sensorData.gyro.z // introduce new value
        sumZ += az[az.count-1] // new sum of last three values
        movingAvg = sumZ/az.count
        
        if movingAvg > gyroTrigger {return PostureStatus.Left}
        else if movingAvg < -gyroTrigger {return PostureStatus.Right}
        
        return PostureStatus.OK
    }
    
    func didConnect() {
        // bluetooth connection is now established
    }
    
    func receiveData(rxData : NSData){
        if (isViewLoaded() && view.window != nil) {
            if let rx = NSString(bytes: rxData.bytes, length: rxData.length, encoding: NSUTF8StringEncoding) {
                receiveRX(rx);
            }
        }
        
    }
    
}





