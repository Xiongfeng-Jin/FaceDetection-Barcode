//
//  CameraView.swift
//  practice9
//
//  Created by Jin on 8/2/17.
//  Copyright © 2017 Jin. All rights reserved.
//

import UIKit
import AVFoundation

class CameraView: UIView {
    var previewLayer:AVCaptureVideoPreviewLayer{
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    var session: AVCaptureSession{
        get{
            return previewLayer.session
        }
        set{
            previewLayer.session = newValue
        }
    }
    
    override class var layerClass:AnyClass{
        return AVCaptureVideoPreviewLayer.self
    }
    
}
