//
//  OpenCVViewController.swift
//  FaceMorpher
//
//  Created by Dmitry Rybochkin on 29.11.2017.
//  Copyright © 2017 Dmitry Rybochkin. All rights reserved.
//

import AVFoundation
import UIKit

class OpenCVViewController: UIViewController {
    
    let scaleFactor: CGFloat = 0.25
    let faceCascadeFilename = "haarcascade_frontalface_alt_tree"
    let eyesCascadeFilename = "haarcascade_frontalface_alt_tree"
    let noseCascadeFilename = "haarcascade_frontalface_alt_tree"
    let mouthCascadeFilename = "haarcascade_frontalface_alt_tree"

    @IBOutlet weak var cameraLiveView: UIView?
    @IBOutlet weak var photoPreviewView: UIView?
    @IBOutlet weak var cameraTypeSwitch: UISwitch?
    @IBOutlet weak var cameraLiveViewTopConstraint: NSLayoutConstraint?

    var faceViews: [UIView] = []
    var isSingleFace = true

    var captureSession: AVCaptureSession?
    var captureDeviceInput: AVCaptureDeviceInput?
    var captureVideoDataOutput: AVCaptureVideoDataOutput?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    
    var openCVWrapper: OpenCVWrapper?
    private var videoOutputQueue = DispatchQueue(label: "videoOutputQueue")
    private let startInterfaceOrientation = UIApplication.shared.statusBarOrientation
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        configureOpenCV()

        cameraTypeSwitch?.isOn = false
        configureCamera()
    }
    
    deinit {
    }
    
    func configureCamera(position: AVCaptureDevice.Position = .back) {
        captureSession?.stopRunning()
//        videoPreviewLayer?.removeFromSuperlayer()
        if let captureDeviceInput = captureDeviceInput {
            captureSession?.removeInput(captureDeviceInput)
        }
//        if let captureVideoDataOutput = captureVideoDataOutput {
//            captureSession?.removeOutput(captureVideoDataOutput)
//        }

        guard let captureDevice = AVCaptureDevice.devices().first(where: { $0.position == position && $0.hasMediaType(.video) }), let inputDevice = try? AVCaptureDeviceInput(device: captureDevice) else {
            print("error AVCaptureDevice")
            return
        }
        
        if captureSession == nil {
            captureSession = AVCaptureSession()
        }
        captureSession?.addInput(inputDevice)
        captureDeviceInput = inputDevice
        
        guard let captureSession = self.captureSession else {
            print("error AVCaptureSession")
            return
        }
        
        if videoPreviewLayer == nil {
            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            
            guard let videoPreviewLayer = self.videoPreviewLayer, let cameraFrame = cameraLiveView?.frame else {
                print("error AVCaptureVideoPreviewLayer")
                return
            }
            
            videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
            switch startInterfaceOrientation {
            case .landscapeLeft:
                videoPreviewLayer.connection?.videoOrientation = .landscapeLeft
                cameraLiveViewTopConstraint?.constant = 0
                videoPreviewLayer.frame = CGRect(x: cameraFrame.origin.x, y: cameraFrame.origin.y, width: cameraFrame.height, height: cameraFrame.width)
            case .landscapeRight:
                videoPreviewLayer.connection?.videoOrientation = .landscapeRight
                cameraLiveViewTopConstraint?.constant = 0
                videoPreviewLayer.frame = CGRect(x: cameraFrame.origin.x, y: cameraFrame.origin.y, width: cameraFrame.height, height: cameraFrame.width)
            case .portrait:
                videoPreviewLayer.connection?.videoOrientation = .portrait
                cameraLiveViewTopConstraint?.constant = UIApplication.shared.statusBarFrame.height
                videoPreviewLayer.frame = cameraFrame
            case .portraitUpsideDown:
                videoPreviewLayer.connection?.videoOrientation = .portraitUpsideDown
                cameraLiveViewTopConstraint?.constant = UIApplication.shared.statusBarFrame.height
                videoPreviewLayer.frame = cameraFrame
            default:
                videoPreviewLayer.connection?.videoOrientation = .portrait
                cameraLiveViewTopConstraint?.constant = UIApplication.shared.statusBarFrame.height
                videoPreviewLayer.frame = cameraFrame
            }
            cameraLiveView?.layer.addSublayer(videoPreviewLayer)
        }
        
        if captureVideoDataOutput == nil {
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
            
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA)];
            
            captureSession.addOutput(videoOutput)
            captureVideoDataOutput = videoOutput
        }
        
        captureSession.startRunning()
    }
    
    func configureOpenCV() {
        openCVWrapper = OpenCVWrapper()
        openCVWrapper?.loadHaarCascades(faceCascadeFilename, eyesCascadeFilename, noseCascadeFilename, mouthCascadeFilename)
        print(openCVWrapper?.openCVVersionString() ?? "opencv version detect error")
    }
    
    func rectForVideoFrame(faceFrame: CGRect, videoFrame: CGRect, videoOrientation: AVCaptureVideoOrientation) -> CGRect? {
        guard let previewFrame = cameraLiveView?.frame else {
            print("nil")
            return nil
        }
        
        var widthScale: CGFloat = 1.0
        var heightScale: CGFloat = 1.0
        
        var resultFrame: CGRect? = nil
        if startInterfaceOrientation.isPortrait, UIDevice.current.orientation.isPortrait {
            print("isPortrait \(videoFrame) \(previewFrame)")
            widthScale = previewFrame.height / (videoFrame.width * scaleFactor)
            heightScale = previewFrame.width / (videoFrame.height * scaleFactor)
            let maxScale = max(widthScale, heightScale)
            let tempFrame = faceFrame.applying(CGAffineTransform(scaleX: maxScale, y: maxScale))
            if UIDevice.current.orientation == .portraitUpsideDown {
                resultFrame = CGRect(x: previewFrame.width - tempFrame.width - tempFrame.origin.x, y: previewFrame.height - tempFrame.height - tempFrame.origin.y, width: tempFrame.width, height: tempFrame.height)
                print("\(tempFrame.origin)")
            } else {
                resultFrame = tempFrame
            }
        } else if startInterfaceOrientation.isLandscape, UIDevice.current.orientation.isLandscape {
            print("isLandscape \(videoFrame)  \(previewFrame)")
            widthScale = previewFrame.height / (videoFrame.height * scaleFactor)
            heightScale = previewFrame.width / (videoFrame.width * scaleFactor)
            let maxScale = max(widthScale, heightScale)
            let tempFrame = faceFrame.applying(CGAffineTransform(scaleX: maxScale, y: maxScale))
            if (UIDevice.current.orientation == .landscapeRight && startInterfaceOrientation == .landscapeRight) || (UIDevice.current.orientation == .landscapeLeft && startInterfaceOrientation == .landscapeLeft) {
                resultFrame = CGRect(x: previewFrame.width - tempFrame.width - tempFrame.origin.x, y: previewFrame.height - tempFrame.height - tempFrame.origin.y, width: tempFrame.width, height: tempFrame.height)
            } else {
                 resultFrame = tempFrame
            }
        } else if startInterfaceOrientation.isPortrait {
            print("isPortrait to isLandscape \(videoFrame) \(previewFrame)")
            widthScale = previewFrame.height / (videoFrame.width * scaleFactor)
            heightScale = previewFrame.width / (videoFrame.height * scaleFactor)
            let maxScale = max(widthScale, heightScale)
            let tempFrame = faceFrame.applying(CGAffineTransform(scaleX: maxScale, y: maxScale))
            if UIDevice.current.orientation == .landscapeRight {
                resultFrame = CGRect(x: tempFrame.origin.y, y: previewFrame.height - tempFrame.height - tempFrame.origin.x, width: tempFrame.width, height: tempFrame.height)
             } else {
                resultFrame = CGRect(x: previewFrame.width - tempFrame.width - tempFrame.origin.y, y: tempFrame.origin.x, width: tempFrame.width, height: tempFrame.height)
            }
        } else {
            print("isLandscape to isPortrait \(videoFrame) \(previewFrame)")
            widthScale = previewFrame.height / (videoFrame.height * scaleFactor)
            heightScale = previewFrame.width / (videoFrame.width * scaleFactor)
            let maxScale = max(widthScale, heightScale)
            let tempFrame = faceFrame.applying(CGAffineTransform(scaleX: maxScale, y: maxScale))
            if UIDevice.current.orientation == .portraitUpsideDown && startInterfaceOrientation == .landscapeLeft || UIDevice.current.orientation == .portrait && startInterfaceOrientation == .landscapeRight {
                resultFrame = CGRect(x: tempFrame.origin.y, y: previewFrame.height - tempFrame.height - tempFrame.origin.x, width: tempFrame.width, height: tempFrame.height)
            } else {
                resultFrame = CGRect(x: previewFrame.width - tempFrame.width - tempFrame.origin.y, y: tempFrame.origin.x, width: tempFrame.width, height: tempFrame.height)
            }
       }
        return resultFrame
    }
    
    func transformForFace() -> CGAffineTransform {
        var multyPi: CGFloat = 0
        
        switch startInterfaceOrientation {
        case .landscapeLeft:
            switch UIDevice.current.orientation {
            case.landscapeLeft:
                multyPi = 1.0
            case .landscapeRight:
                multyPi = 0
            case .portrait:
                multyPi = 1.0 / 2.0
            case .portraitUpsideDown:
                multyPi = 3.0 / 2.0
            default:
                break
            }
        case .landscapeRight:
            switch UIDevice.current.orientation {
            case.landscapeLeft:
                multyPi = 0
            case .landscapeRight:
                multyPi = 1.0
            case .portrait:
                multyPi = 3.0 / 2.0
            case .portraitUpsideDown:
                multyPi = 1.0 / 2.0
            default:
                break
            }
        case .portrait:
            switch UIDevice.current.orientation {
            case.landscapeLeft:
                multyPi = 1.0 / 2.0
            case .landscapeRight:
                multyPi = 3.0 / 2.0
            case .portrait:
                multyPi = 0
            case .portraitUpsideDown:
                multyPi = 1.0
            default:
                break
            }
        case .portraitUpsideDown:
            switch UIDevice.current.orientation {
            case.landscapeLeft:
                multyPi = 3.0 / 2.0
            case .landscapeRight:
                multyPi = 1.0 / 2.0
            case .portrait:
                multyPi = 1.0
            case .portraitUpsideDown:
                multyPi = 0
            default:
                break
            }
        default:
            break
        }
        
        return CGAffineTransform(rotationAngle: multyPi * CGFloat.pi)
    }
    
    @IBAction func singleFaceSwicthChanged(_ sender: UISwitch) {
        isSingleFace = sender.isOn
    }

    @IBAction func cameraTypeSwicthChanged(_ sender: UISwitch) {
        //configureOpenCV()
        configureCamera(position: sender.isOn ? .front : .back)
    }
}


extension OpenCVViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func updateFace(in faceView: UIView?, frame: CGRect, videoFrame: CGRect, videoOrientation: AVCaptureVideoOrientation) {
        guard let faceFrame = rectForVideoFrame(faceFrame: frame, videoFrame: videoFrame, videoOrientation: videoOrientation) else {
            faceView?.isHidden = true
            return
        }
        faceView?.frame = faceFrame
        faceView?.transform = transformForFace()
        faceView?.isHidden = false
  }
    
    func display(faces: [CGRect], videoFrame: CGRect, videoOrientation: AVCaptureVideoOrientation) {
        print("\(faces.count) faces have found \(faces.first ?? CGRect.zero)")
        DispatchQueue.main.async { [weak self] in
            let faceViewCount = self?.faceViews.count ?? 0
            
            if faceViewCount > faces.count {
                for index in faces.count..<faceViewCount {
                    self?.faceViews[index].isHidden = true
                }
            } else if faceViewCount < faces.count {
                for _ in faceViewCount..<faces.count {
                    let faceView = UIView()
                    faceView.backgroundColor = UIColor.red.withAlphaComponent(0.25)
                    self?.faceViews.append(faceView)
                    self?.view.addSubview(faceView)
                }
            }
            for index in 0..<faces.count {
                if self?.faceViews[index].isHidden ?? false {
                    self?.faceViews[index].isHidden = false
                }
                self?.updateFace(in: self?.faceViews[index], frame: faces[index], videoFrame: videoFrame, videoOrientation: videoOrientation)
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let videoOrientation = connection.videoOrientation
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
            let faces = openCVWrapper?.processFrame(pixelBuffer, videoOrientation, scaleFactor, isSingleFace) as? [CGRect],
            !faces.isEmpty else {
                faceViews.forEach({ $0.isHidden = true })
            return
        }
        let videoRect = CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        display(faces: faces, videoFrame: videoRect, videoOrientation: videoOrientation)
    }
}

