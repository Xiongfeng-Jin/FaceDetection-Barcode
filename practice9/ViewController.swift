//
//  ViewController.swift
//  practice9
//
//  Created by Jin on 8/2/17.
//  Copyright © 2017 Jin. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    @IBOutlet weak var cameraView: CameraView!
    @IBOutlet weak var zommSlider: UISlider!
    @IBOutlet weak var metadataButton: UIButton!
    @IBOutlet weak var presetsButton: UIButton!
    @IBOutlet weak var cameraButton: UIButton!

    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.metadataButton.isEnabled = true
        self.presetsButton.isEnabled = true
        self.cameraButton.isEnabled = true
        self.zommSlider.isEnabled = true
        
        cameraView.session = session
        cameraView.addGestureRecognizer(openBarcodeURLGestureRecognizer)
        
        switch AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo){ granted in
                if !granted{
                    print("cannot get camera")
                    assert(granted)
                }
            }
        default:
            break
        }
        
        sessionQueue.async { [unowned self] in
            self.configureSession()
        }
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        sessionQueue.async { [unowned self] in
            self.session.startRunning()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        sessionQueue.async { [unowned self] in
            self.session.stopRunning()
        }
    }

    
    private func configureSession(){
        session.beginConfiguration()
        
        do{
            var defaultVideoDevice: AVCaptureDevice?
            
            if let dualCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInDualCamera, mediaType: AVMediaTypeVideo, position: .back){
                defaultVideoDevice = dualCameraDevice
            }
            else if let backCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .back){
                defaultVideoDevice = backCameraDevice
            }
            else if let frontCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .front){
                defaultVideoDevice = frontCameraDevice
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: defaultVideoDevice)
            
            if session.canAddInput(videoDeviceInput){
                session.addInput(videoDeviceInput)
                self.videoInput = videoDeviceInput
                
                DispatchQueue.main.async {
                    let statusBarOrientation = UIApplication.shared.statusBarOrientation
                    var initialVideoOrientation: AVCaptureVideoOrientation = .portrait
                    if statusBarOrientation != .unknown {
                        if let videoOrientation = statusBarOrientation.videoOrientation {
                            initialVideoOrientation = videoOrientation
                        }
                    }
                    
                    self.cameraView.previewLayer.connection.videoOrientation = initialVideoOrientation
                    self.zommSlider.maximumValue = Float(min(self.videoInput.device.activeFormat.videoMaxZoomFactor, CGFloat(8.0)))
                    self.zommSlider.value = Float(self.videoInput.device.videoZoomFactor)
                }
            }
            else{
                print("cannot add video input device to the session")
                session.commitConfiguration()
                return
            }
        }
        catch{
            print("cannot create video device input :\(error)")
            session.commitConfiguration()
            return
        }
        
        if session.canAddOutput(metadataOutput){
            session.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: metadataObjectsQueue)
            metadataOutput.metadataObjectTypes = metadataOutput.availableMetadataObjectTypes
            metadataOutput.rectOfInterest = cameraView.bounds
        }
        else{
            print("cannot add metadata output to the session")
            session.commitConfiguration()
            return
        }
        session.commitConfiguration()
        
    }
    
    private let videoDeviceDiscoverSession = AVCaptureDeviceDiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera], mediaType: AVMediaTypeVideo, position: .unspecified)!
    
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "session queue",attributes:[],target: nil)
    private let metadataOutput = AVCaptureMetadataOutput()
    private let metadataObjectsQueue = DispatchQueue(label: "metadata objects queue", attributes:[],target: nil)
    
    var videoInput:AVCaptureDeviceInput!
    
    
    @IBAction func changeCamera(_ sender: UIButton) {
        removeMetadataObjectOverlayLayers()
        
        DispatchQueue.main.async { [unowned self] in
            let currentVideoDeivce = self.videoInput.device
            let currentPosition = currentVideoDeivce!.position
            
            let preferredPosition: AVCaptureDevicePosition
            let preferredDeviceType: AVCaptureDeviceType
            
            switch currentPosition{
            case .unspecified, .front:
                preferredPosition = .back
                preferredDeviceType = .builtInDualCamera
            case .back:
                preferredPosition = .front
                preferredDeviceType = .builtInWideAngleCamera
            }
            
            let devices = self.videoDeviceDiscoverSession.devices!
            var newVideoDevice: AVCaptureDevice? = nil
            
            if let device = devices.filter({ $0.position == preferredPosition && $0.deviceType == preferredDeviceType}).first{
                newVideoDevice = device
            }
            else if let device = devices.filter({ $0.position == preferredPosition}).first{
                newVideoDevice = device
            }
            
            if let videoDevice = newVideoDevice{
                do{
                    let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                    self.session.beginConfiguration()
                    self.session.removeInput(self.videoInput)
                    
                    let previousSessionPreset = self.session.sessionPreset
                    self.session.sessionPreset = AVCaptureSessionPresetHigh
                    
                    if self.session.canAddInput(videoDeviceInput){
                        self.session.addInput(videoDeviceInput)
                        self.videoInput = videoDeviceInput
                    }
                    else{
                        self.session.addInput(self.videoInput)
                    }
                    
                    if self.session.canSetSessionPreset(previousSessionPreset){
                        self.session.sessionPreset = previousSessionPreset
                    }
                    
                    self.session.commitConfiguration()
                    
                }
                catch{
                    print("error happened while creating video device input: \(error)")
                }
            }
            
            DispatchQueue.main.async { [unowned self] in
                self.metadataButton.isEnabled = true
                self.presetsButton.isEnabled = true
                self.cameraButton.isEnabled = true
                self.zommSlider.isEnabled = true
                self.zommSlider.maximumValue = Float(min(self.videoInput.device.activeFormat.videoMaxZoomFactor, CGFloat(8.0)))
                self.zommSlider.value = Float(self.videoInput.device.videoZoomFactor)
            }

        }
    }
    
    @objc private func removeMetadataObjectOverlayLayers(){
        for sublayer in metadataObjectOverlayLayers{
            sublayer.removeFromSuperlayer()
        }
        metadataObjectOverlayLayers = []
        
        removeMetadataObjectOverlayLayerstimer?.invalidate()
        removeMetadataObjectOverlayLayerstimer = nil
    }
    
    private class MetadataObjectLayer: CAShapeLayer{
        var metadataObject:AVMetadataObject?
    }
    
    private var removeMetadataObjectOverlayLayerstimer:Timer?
    private let metadataObjectOverlayLayerDrawingSemaphore = DispatchSemaphore(value: 1)
    
    private var metadataObjectOverlayLayers = [MetadataObjectLayer]()
    
    
    @IBAction func zoomCamera(_ sender: UISlider) {
        do{
            try videoInput.device.lockForConfiguration()
            videoInput.device.videoZoomFactor = CGFloat(zommSlider.value)
            videoInput.device.unlockForConfiguration()
        }
        catch{
            print("cannot lock for configureatin \(error)")
        }
    }
    
    private func createMetadataObjectOverLayWithMetadataObject(_ metadataObject: AVMetadataObject) -> MetadataObjectLayer{
        let transformedMetadataObejct = cameraView.previewLayer.transformedMetadataObject(for: metadataObject)
        
        let metadataObjectOverlayLayer = MetadataObjectLayer()
        metadataObjectOverlayLayer.metadataObject = transformedMetadataObejct
        metadataObjectOverlayLayer.lineJoin = kCALineJoinRound
        metadataObjectOverlayLayer.lineWidth = 5.0
        metadataObjectOverlayLayer.strokeColor = view.tintColor.withAlphaComponent(0.5).cgColor
        metadataObjectOverlayLayer.fillColor = view.tintColor.withAlphaComponent(0.3).cgColor
        
        if transformedMetadataObejct is AVMetadataMachineReadableCodeObject{
            let barcodeMetadataObject = transformedMetadataObejct as! AVMetadataMachineReadableCodeObject
            
            let barcodeOverlayPath = barcodeOverlayPathWithCorners(barcodeMetadataObject.corners as! [CFDictionary])
            
            metadataObjectOverlayLayer.path = barcodeOverlayPath
            
            if barcodeMetadataObject.stringValue.characters.count > 0{
                let barcodeOverlayBoundingBox = barcodeOverlayPath.boundingBox
                
                let textLayer = CATextLayer()
                textLayer.alignmentMode = kCAAlignmentCenter
                textLayer.bounds = CGRect(x: 0, y: 0, width: barcodeOverlayBoundingBox.size.width, height: barcodeOverlayBoundingBox.size.height)
                textLayer.contentsScale = UIScreen.main.scale
                textLayer.font = UIFont.boldSystemFont(ofSize: 19).fontName as CFString
                textLayer.position = CGPoint(x: barcodeOverlayBoundingBox.midX, y: barcodeOverlayBoundingBox.midY)
                textLayer.string = NSAttributedString(string: barcodeMetadataObject.stringValue, attributes: [
                    NSFontAttributeName:UIFont.boldSystemFont(ofSize: 19),
                    kCTForegroundColorAttributeName as String : UIColor.white.cgColor,
                    kCTStrokeWidthAttributeName as String : -5.0,
                    kCTStrokeColorAttributeName as String : UIColor.black.cgColor
                    ])
                textLayer.isWrapped = true
                print(barcodeMetadataObject.stringValue)
                textLayer.transform = CATransform3DInvert(CATransform3DMakeAffineTransform(cameraView.transform))
                metadataObjectOverlayLayer.addSublayer(textLayer)
            }
        }
        else if transformedMetadataObejct is AVMetadataFaceObject{
            metadataObjectOverlayLayer.path = CGPath(rect: transformedMetadataObejct!.bounds, transform: nil)
        }
        return metadataObjectOverlayLayer
    }
    
    private func barcodeOverlayPathWithCorners(_ corners: [CFDictionary]) -> CGMutablePath{
        let path = CGMutablePath()
        
        if !corners.isEmpty{
            guard let corner = CGPoint(dictionaryRepresentation: corners[0]) else {
                return path
            }
            path.move(to: corner, transform: .identity)
            
            for cornerDictionary in corners{
                guard let corner = CGPoint(dictionaryRepresentation: cornerDictionary) else{ return path}
                path.addLine(to: corner)
            }
            path.closeSubpath()
        }
        return path
    }
    
    private func addMetadataObjectOverlayLayersToCameraView(_ metadataObjectOverlayLayers:[MetadataObjectLayer]){
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for metadataObjectOverlayLayer in metadataObjectOverlayLayers{
            cameraView.previewLayer.addSublayer(metadataObjectOverlayLayer)
        }
        CATransaction.commit()
        self.metadataObjectOverlayLayers = metadataObjectOverlayLayers
        
        removeMetadataObjectOverlayLayerstimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(removeMetadataObjectOverlayLayers), userInfo: nil, repeats: false)
    }
    
    @objc private func openBarcodeURL(with openBarcodeURLGestureRecognizer:UITapGestureRecognizer){
        for metadataobjectOverlayLayer in metadataObjectOverlayLayers{
            if metadataobjectOverlayLayer.path!.contains(openBarcodeURLGestureRecognizer.location(in: cameraView),using: .winding, transform: .identity){
                if let barcodeMetadataObject = metadataobjectOverlayLayer.metadataObject as? AVMetadataMachineReadableCodeObject{
                    if barcodeMetadataObject.stringValue != nil{
                        if let url = URL(string: barcodeMetadataObject.stringValue), UIApplication.shared.canOpenURL(url){
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        }
                    }
                }
            }
        }
    }
    
    private lazy var openBarcodeURLGestureRecognizer:UITapGestureRecognizer = {
        UITapGestureRecognizer(target: self, action: #selector(openBarcodeURL(with:)))
    }()
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
        print(metadataObjects.count)
        if metadataObjectOverlayLayerDrawingSemaphore.wait(timeout: DispatchTime.now()) == .success{
            DispatchQueue.main.async { [unowned self] in
                self.removeMetadataObjectOverlayLayers()
                var metadataObjectOverlayLayers = [MetadataObjectLayer]()
                for metadataObject in metadataObjects as! [AVMetadataObject] {
                    let metadataObjectOverlaylayer = self.createMetadataObjectOverLayWithMetadataObject(metadataObject)
                    metadataObjectOverlayLayers.append(metadataObjectOverlaylayer)
                }
                
                self.addMetadataObjectOverlayLayersToCameraView(metadataObjectOverlayLayers)
                self.metadataObjectOverlayLayerDrawingSemaphore.signal()
            }
        }
    }
    
    
    
    
    
}// end of class

extension AVCaptureDeviceDiscoverySession{
    func uniqueDevicePositionsCount() -> Int{
        var uniqueDevicePositions = [AVCaptureDevicePosition]()
        
        for device in devices{
            if !uniqueDevicePositions.contains(device.position){
                uniqueDevicePositions.append(device.position)
            }
        }
        return uniqueDevicePositions.count
    }
}


extension UIDeviceOrientation{
    var videoOrientation: AVCaptureVideoOrientation?{
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
        default: return nil
        }
    }
}

extension UIInterfaceOrientation{
    var videoOrientation:AVCaptureVideoOrientation? {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default:
            return nil
        }
    }
}
