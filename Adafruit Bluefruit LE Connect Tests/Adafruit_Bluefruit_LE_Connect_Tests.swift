//
//  Adafruit_Bluefruit_LE_Connect_Tests.swift
//  Adafruit Bluefruit LE Connect Tests
//
//  Created by Helen Diacono on 7/10/2015.
//  Copyright © 2015 Adafruit Industries. All rights reserved.
//

import XCTest

let minSense = -0x4_000  // = -2^14
let maxSense = 0x4_000  // = +2^14

class Adafruit_Bluefruit_LE_Connect_Tests: XCTestCase {
    
    var vc:PostureViewController?
    var testSensor = SensorData(
        accel: Vector(x: 0,y: 0,z: 0),
        mag: Vector(x: 0,y: 0,z: 0),
        gyro: Vector(x: 0,y: 0,z: 0))
    var status: PostureStatus = PostureStatus.OK
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        vc = PostureViewController()
        srandom(UInt32(time(nil)))
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func randomSense(min min: Int = minSense, max: Int = maxSense) -> Int {
        return Int(arc4random_uniform(UInt32(max-min+1))) + min
    }

    func prepSensorData(posture: PostureStatus) {
        testSensor.accel.x = randomSense()
        testSensor.accel.y = randomSense()
        testSensor.accel.z = randomSense()
        testSensor.gyro.y = randomSense()
        switch posture {
        case PostureStatus.OK:
            testSensor.gyro.x = randomSense(min: -gyroTrigger, max: gyroTrigger)
            testSensor.gyro.z = randomSense(min: -gyroTrigger, max: gyroTrigger)
        case PostureStatus.Forward:
            testSensor.gyro.x = randomSense(min: gyroTrigger+1, max: maxSense)
            testSensor.gyro.z = randomSense(min: -gyroTrigger, max: gyroTrigger)
        case PostureStatus.Back:
            testSensor.gyro.x = randomSense(min: minSense, max: -gyroTrigger-1)
            testSensor.gyro.z = randomSense(min: -gyroTrigger, max: gyroTrigger)
        case PostureStatus.Left:
            testSensor.gyro.x = randomSense(min: -gyroTrigger, max: gyroTrigger)
            testSensor.gyro.z = randomSense(min: gyroTrigger+1, max: maxSense)
        case PostureStatus.Right:
            testSensor.gyro.x = randomSense(min: -gyroTrigger, max: gyroTrigger)
            testSensor.gyro.z = randomSense(min: minSense, max: -gyroTrigger-1)
        }
        testSensor.mag.x = randomSense()
        testSensor.mag.y = randomSense()
        testSensor.mag.z = randomSense()
    }
    
    func testCalculatePostureStatusGood() {
        for i in 1...triggerCount+2 {
            prepSensorData(PostureStatus.OK)
            status = vc!.calculatePostureStatus(testSensor)
            if i > triggerCount {
                XCTAssert(status == PostureStatus.OK, "sent good posture data but did not get an OK response")
            }
        }
    }
    
    func testCalculatePostureStatusMixed() {
        // send mix of bad posture data but fewer than triggerCount in a row
        testCalculatePostureStatusGood() // send some good posture data to begin with
        // then send data representing lean forward posture data
        
        for _ in 1..<triggerCount {
            prepSensorData(PostureStatus.Forward)
            testSensor.gyro.x = randomSense(min: gyroTrigger+1, max: gyroTrigger+gyroTrigger/triggerCount)
            XCTAssert(vc!.calculatePostureStatus(testSensor) == PostureStatus.OK, "sent too few lean forward posture data but didn't get OK response")
        }
        // then send data representing lean back posture data
        for _ in 1..<triggerCount {
            prepSensorData(PostureStatus.Back)
            testSensor.gyro.x = randomSense(min: -gyroTrigger-gyroTrigger/triggerCount, max: -gyroTrigger-1)
            XCTAssert(vc!.calculatePostureStatus(testSensor) == PostureStatus.OK, "sent too few lean back posture data but didn't get OK response")
        }
        // nullify any lingering "back" measurements with a forward one
        testSensor.gyro.x = randomSense(min: gyroTrigger+1, max: gyroTrigger+gyroTrigger/triggerCount)
        XCTAssert(vc!.calculatePostureStatus(testSensor) == PostureStatus.OK, "sent too few lean forward posture data but didn't get OK response")
        // then send data representing lean left posture data
        for _ in 1..<triggerCount {
            prepSensorData(PostureStatus.Left)
            testSensor.gyro.z = randomSense(min: gyroTrigger+1, max: gyroTrigger+gyroTrigger/triggerCount)
            XCTAssert(vc!.calculatePostureStatus(testSensor) == PostureStatus.OK, "sent too few lean left posture data but didn't get OK response")
        }
        // then send data representing lean right posture data
        for _ in 1..<triggerCount {
            prepSensorData(PostureStatus.Right)
            testSensor.gyro.z = randomSense(min: -gyroTrigger-gyroTrigger/triggerCount, max: -gyroTrigger-1)
            XCTAssert(vc!.calculatePostureStatus(testSensor) == PostureStatus.OK, "sent too few lean right posture data but didn't get OK response")
        }
        testCalculatePostureStatusGood() // send some more good posture data
    }
    
    func testCalculatePostureStatusBad() {
        testCalculatePostureStatusGood() // send some good posture data to begin with
        // then send data representing lean forward posture data
        for _ in 1...triggerCount {
            prepSensorData(PostureStatus.Forward)
            status = vc!.calculatePostureStatus(testSensor)
        }
        XCTAssert( status == PostureStatus.Forward, "sent lean forward posture data but didn't get 'forward' response")
        testCalculatePostureStatusGood() // send some more good posture data
        // then send data representing lean back posture data
        for _ in 1...triggerCount {
            prepSensorData(PostureStatus.Back)
            status = vc!.calculatePostureStatus(testSensor)
        }
        XCTAssert( status == PostureStatus.Back, "sent lean back posture data but didn't get 'back' response")
        testCalculatePostureStatusGood() // send some more good posture data
        // then send data representing lean left posture data
        for _ in 1...triggerCount {
            prepSensorData(PostureStatus.Left)
            status = vc!.calculatePostureStatus(testSensor)
        }
        XCTAssert( status == PostureStatus.Left, "sent lean left posture data but didn't get 'left' response")
        testCalculatePostureStatusGood() // send some more good posture data
        // then send data representing lean right posture data
        for _ in 1...triggerCount {
            prepSensorData(PostureStatus.Right)
            status = vc!.calculatePostureStatus(testSensor)
        }
        XCTAssert( status == PostureStatus.Right, "sent lean right posture data but didn't get 'right' response")
    }
    
    func testParseBadData() {
        let parsed = vc!.parse("!A0123.45@hello there!")
        XCTAssert(parsed == nil, "sent bad data to be parsed but didn't get nil SensorData returned")
    }
    
    func testParseGoodData() {
        var dataGood: Bool = false
        let parsed = vc!.parse("!A0-1037.00@-14939.00@6112.00!G0194.00@-116.00@-266.00!M0870.00@-3623.00@-1348.00")
        XCTAssert(parsed != nil, "parsed returned a nil value to good data")
        if (parsed != nil) {
            dataGood =
                parsed!.accel.x == -1037 &&
                parsed!.accel.y == -14939 &&
                parsed!.accel.z == 6112 &&
                parsed!.gyro.x == 194 &&
                parsed!.gyro.y == -116 &&
                parsed!.gyro.z == -266 &&
                parsed!.mag.x == 870 &&
                parsed!.mag.y == -3623 &&
                parsed!.mag.z == -1348
            XCTAssert(dataGood == true, "parsed returned incorrect SensorData")
        }
    }
    
    func testunParseBadData() {
        let txString = vc!.unParse(9)
        XCTAssert(txString == "", "unParse didn't return an empty string for bad data")
    }

    func testunParseGoodData() {
        let txString = vc!.unParse(1)
        XCTAssert(txString == "!B1@", "Asked unParse for string to turn on vibe motor 1 but didn't get correct txString")
    }
}
