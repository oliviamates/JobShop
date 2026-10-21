//
//  UploadResumeVC.swift
//  JobShop
//
//  Created by Mansi Madhani on 10/20/26.
//

import UIKit
import UniformTypeIdentifiers


class UploadResumeVC: UIViewController, UIDocumentPickerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func uploadButtonTapped(_ sender: Any) {
        let supportedTypes: [UTType] = [.pdf]
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
            picker.delegate = self
            picker.allowsMultipleSelection = false
            present(picker, animated: true, completion: nil)
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let selectedFileURL = urls.first else { return }
            uploadFile(fileURL: selectedFileURL)
        }
    
    func uploadFile(fileURL: URL) {
        print("placeholder")
    }
    
    @IBAction func openCamera(_ sender: Any) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                let picker = UIImagePickerController()
                picker.delegate = self
                picker.sourceType = .camera
                present(picker, animated: true, completion: nil)
            } else {
                print("Camera not available on this device.")
            }
        }
    

    @IBAction func cancelPressed(_ sender: Any) {
        dismiss(animated: true)
    }
    @IBAction func savePressed(_ sender: Any) {
        dismiss(animated: true)
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
